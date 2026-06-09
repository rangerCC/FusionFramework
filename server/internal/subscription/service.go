package subscription

import (
	"context"
	"encoding/json"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/appstore"
	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// Service holds subscription use-cases.
type Service struct {
	repo     *repo
	verifier appstore.Verifier
	// expectedEnv is the App Store environment this deployment trusts
	// ("Production" or "Sandbox"); strictEnv rejects mismatches.
	expectedEnv string
	strictEnv   bool
}

func NewService(pool *pgxpool.Pool, ids *idgen.Snowflake, v appstore.Verifier, expectedEnv string, strictEnv bool) *Service {
	return &Service{
		repo:        &repo{pool: pool, ids: ids},
		verifier:    v,
		expectedEnv: expectedEnv,
		strictEnv:   strictEnv,
	}
}

// envAllowed reports whether a transaction/notification environment may be
// processed by this deployment. Blocks sandbox purchases from granting prod
// entitlements (and vice versa) when strict mode is on.
func (s *Service) envAllowed(env string) bool {
	if !s.strictEnv || s.expectedEnv == "" {
		return true
	}
	return defaultEnv(env) == s.expectedEnv
}

// IsActive implements usage.SubChecker.
func (s *Service) IsActive(ctx context.Context, userID int64) (bool, error) {
	sub, err := s.repo.activeForUser(ctx, userID)
	if err != nil {
		return false, err
	}
	return sub != nil, nil
}

// Current returns the user's current entitlement view.
func (s *Service) Current(ctx context.Context, userID int64) (*Sub, error) {
	return s.repo.activeForUser(ctx, userID)
}

// UserToken returns the user's app_account_token.
func (s *Service) UserToken(ctx context.Context, userID int64) (string, error) {
	return s.repo.appAccountToken(ctx, userID)
}

// statusFromExpiry derives a coarse status from the expiry date.
func statusFromExpiry(exp *time.Time) string {
	if exp == nil {
		return "active"
	}
	if exp.After(time.Now()) {
		return "active"
	}
	return "expired"
}

// Verify looks up a transaction at Apple, confirms ownership, and upserts.
func (s *Service) Verify(ctx context.Context, userID int64, userToken, transactionID string) (*Sub, error) {
	info, err := s.verifier.LookupTransaction(transactionID)
	if err != nil {
		return nil, httpx.ErrTxVerify
	}
	if !s.envAllowed(info.Environment) {
		// e.g. a Sandbox transaction submitted to the Production deployment.
		return nil, httpx.ErrTxVerify
	}
	if info.AppAccountToken != "" && userToken != "" && info.AppAccountToken != userToken {
		return nil, httpx.ErrTxNotOwned
	}
	exp := nilableTime(info.ExpiresDate)
	if err := s.repo.upsert(ctx, userID, upsertSub{
		OriginalTransactionID: info.OriginalTransactionID,
		LatestTransactionID:   info.TransactionID,
		ProductID:             info.ProductID,
		Status:                statusFromExpiry(exp),
		ExpiresAt:             exp,
		AutoRenew:             true,
		Environment:           defaultEnv(info.Environment),
		AppAccountToken:       info.AppAccountToken,
	}); err != nil {
		return nil, httpx.ErrSubSync
	}
	return s.repo.activeForUser(ctx, userID)
}

// HandleNotification processes an App Store Server Notification V2 (idempotent).
func (s *Service) HandleNotification(ctx context.Context, signedPayload string) error {
	payload, err := s.verifier.ParseNotification(signedPayload)
	if err != nil {
		return err
	}
	// Idempotency: skip if already recorded.
	if payload.NotificationUUID != "" {
		seen, err := s.repo.eventSeen(ctx, payload.NotificationUUID)
		if err == nil && seen {
			return nil
		}
	}
	raw, _ := json.Marshal(payload)
	_ = s.repo.recordEvent(ctx, eventRow{
		OriginalTransactionID: orig(payload),
		NotificationType:      payload.NotificationType,
		Subtype:               payload.Subtype,
		NotificationUUID:      payload.NotificationUUID,
		Environment:           defaultEnv(payload.Environment),
		SignedDate:            payload.SignedDate,
		RawPayload:            raw,
	})

	tx := payload.Transaction
	if tx == nil || tx.AppAccountToken == "" {
		return nil // nothing to map
	}
	if !s.envAllowed(tx.Environment) {
		// Event is logged above for audit, but a mismatched-environment
		// notification must not mutate this deployment's entitlements.
		return nil
	}
	userID, err := s.repo.userIDByAppAccountToken(ctx, tx.AppAccountToken)
	if err != nil || userID == 0 {
		return nil // unknown token; event is still logged
	}
	status := statusForType(payload.NotificationType, tx.ExpiresDate)
	autoRenew := true
	if payload.Renewal != nil {
		autoRenew = payload.Renewal.AutoRenewStatus
	}
	exp := nilableTime(tx.ExpiresDate)
	return s.repo.upsert(ctx, userID, upsertSub{
		OriginalTransactionID: tx.OriginalTransactionID,
		LatestTransactionID:   tx.TransactionID,
		ProductID:             tx.ProductID,
		Status:                status,
		ExpiresAt:             exp,
		AutoRenew:             autoRenew,
		Environment:           defaultEnv(tx.Environment),
		AppAccountToken:       tx.AppAccountToken,
	})
}

func statusForType(notifType string, exp time.Time) string {
	switch notifType {
	case "EXPIRED", "GRACE_PERIOD_EXPIRED":
		return "expired"
	case "REVOKE", "REFUND":
		return "revoked"
	case "DID_CHANGE_RENEWAL_STATUS", "DID_RENEW", "SUBSCRIBED":
		if !exp.IsZero() && exp.Before(time.Now()) {
			return "expired"
		}
		return "active"
	default:
		if !exp.IsZero() && exp.Before(time.Now()) {
			return "expired"
		}
		return "active"
	}
}

func orig(p *appstore.NotificationPayload) string {
	if p.Transaction != nil {
		return p.Transaction.OriginalTransactionID
	}
	return ""
}

func nilableTime(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	return &t
}

func defaultEnv(e string) string {
	if e == "" {
		return "Production"
	}
	return e
}

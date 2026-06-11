package appstore

import (
	"context"
	"fmt"
	"os"
	"sync"
	"time"

	iap "github.com/awa/go-iap/appstore"
	iapapi "github.com/awa/go-iap/appstore/api"
)

// TransactionInfo is the decoded JWSTransaction payload (subset we use).
type TransactionInfo struct {
	OriginalTransactionID string
	TransactionID         string
	ProductID             string
	ExpiresDate           time.Time
	AppAccountToken       string
	Environment           string // Production | Sandbox
}

// RenewalInfo is the decoded JWSRenewalInfo payload (subset).
type RenewalInfo struct {
	AutoRenewStatus bool
	ProductID       string
}

// NotificationPayload is the decoded App Store Server Notification V2.
type NotificationPayload struct {
	NotificationType string
	Subtype          string
	NotificationUUID string
	SignedDate       time.Time
	Environment      string
	Transaction      *TransactionInfo
	Renewal          *RenewalInfo
}

// Verifier validates Apple signatures and queries the App Store Server API.
type Verifier interface {
	// ParseNotification verifies the signed payload and decodes it.
	ParseNotification(signedPayload string) (*NotificationPayload, error)
	// LookupTransaction fetches & verifies a single transaction by id.
	LookupTransaction(transactionID string) (*TransactionInfo, error)
}

// DefaultVerifier verifies Apple JWS signatures (x5c chain to the Apple root
// CA, performed inside go-iap) and queries the App Store Server API.
type DefaultVerifier struct {
	BundleID       string
	IssuerID       string
	KeyID          string
	PrivateKeyPath string

	once    sync.Once
	initErr error
	notif   *iap.Client          // verifies notification JWS (cert-chain checked)
	prod    *iapapi.StoreClient  // Server API, Production host
	sandbox *iapapi.StoreClient  // Server API, Sandbox host
}

// apiTimeout bounds each App Store Server API call.
const apiTimeout = 15 * time.Second

// init lazily builds the notification verifier and the two API clients
// (Production + Sandbox). Reading the .p8 key fails loudly here rather than
// silently degrading at request time. The key bytes are never logged.
func (v *DefaultVerifier) init() error {
	v.once.Do(func() {
		key, err := os.ReadFile(v.PrivateKeyPath)
		if err != nil {
			v.initErr = fmt.Errorf("appstore: read private key %q: %w", v.PrivateKeyPath, err)
			return
		}
		base := func(sandbox bool) *iapapi.StoreClient {
			return iapapi.NewStoreClient(&iapapi.StoreConfig{
				KeyContent: key,
				KeyID:      v.KeyID,
				BundleID:   v.BundleID,
				Issuer:     v.IssuerID,
				Sandbox:    sandbox,
			})
		}
		v.notif = iap.New()
		v.prod = base(false)
		v.sandbox = base(true)
	})
	return v.initErr
}

// ParseNotification verifies the V2 notification JWS and the nested signed
// transaction / renewal JWS, then maps them into our subset structs. Every
// signature is validated against Apple's certificate chain by go-iap.
func (v *DefaultVerifier) ParseNotification(signedPayload string) (*NotificationPayload, error) {
	if err := v.init(); err != nil {
		return nil, err
	}

	var decoded iap.SubscriptionNotificationV2DecodedPayload
	if err := v.notif.ParseNotificationV2WithClaim(signedPayload, &decoded); err != nil {
		return nil, fmt.Errorf("appstore: verify notification: %w", err)
	}

	out := &NotificationPayload{
		NotificationType: string(decoded.NotificationType),
		Subtype:          string(decoded.Subtype),
		NotificationUUID: decoded.NotificationUUID,
		Environment:      decoded.Data.Environment,
		SignedDate:       msToTime(decoded.SignedDate),
	}

	// Nested JWS are individually signed; verify each via the cert chain.
	if s := string(decoded.Data.SignedTransactionInfo); s != "" {
		if tx, err := v.prod.ParseSignedTransaction(s); err == nil {
			out.Transaction = mapTransaction(tx)
		} else {
			return nil, fmt.Errorf("appstore: verify transaction info: %w", err)
		}
	}
	if s := string(decoded.Data.SignedRenewalInfo); s != "" {
		if r, err := v.prod.ParseJWSEncodeString(s); err == nil {
			if ri, ok := r.(*iapapi.JWSRenewalInfoDecodedPayload); ok {
				out.Renewal = &RenewalInfo{
					AutoRenewStatus: int(ri.AutoRenewStatus) == 1,
					ProductID:       ri.AutoRenewProductId,
				}
			}
		} else {
			return nil, fmt.Errorf("appstore: verify renewal info: %w", err)
		}
	}
	return out, nil
}

// LookupTransaction queries the App Store Server API for one transaction.
// DefaultVerifier has no environment field, so it follows Apple's guidance:
// try Production first and fall back to Sandbox when the transaction isn't
// found there (TestFlight / review purchases live in Sandbox).
func (v *DefaultVerifier) LookupTransaction(transactionID string) (*TransactionInfo, error) {
	if err := v.init(); err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), apiTimeout)
	defer cancel()

	info, err := v.lookupVia(ctx, v.prod, transactionID)
	if err == nil {
		return info, nil
	}
	// Fall back to Sandbox; a not-found / 404 in Production is expected for
	// sandbox transactions.
	info, sbErr := v.lookupVia(ctx, v.sandbox, transactionID)
	if sbErr == nil {
		return info, nil
	}
	return nil, fmt.Errorf("appstore: lookup %s failed (prod: %v; sandbox: %v)", transactionID, err, sbErr)
}

func (v *DefaultVerifier) lookupVia(ctx context.Context, cli *iapapi.StoreClient, transactionID string) (*TransactionInfo, error) {
	resp, err := cli.GetTransactionInfo(ctx, transactionID)
	if err != nil {
		return nil, err
	}
	tx, err := cli.ParseSignedTransaction(resp.SignedTransactionInfo)
	if err != nil {
		return nil, fmt.Errorf("verify signed transaction: %w", err)
	}
	return mapTransaction(tx), nil
}

// mapTransaction converts go-iap's decoded transaction into our subset.
func mapTransaction(tx *iapapi.JWSTransaction) *TransactionInfo {
	info := &TransactionInfo{
		OriginalTransactionID: tx.OriginalTransactionId,
		TransactionID:         tx.TransactionID,
		ProductID:             tx.ProductID,
		AppAccountToken:       tx.AppAccountToken,
		Environment:           string(tx.Environment),
	}
	if tx.ExpiresDate > 0 {
		info.ExpiresDate = msToTime(tx.ExpiresDate)
	}
	return info
}

// msToTime converts Apple's millisecond epoch timestamps to UTC time.
func msToTime(ms int64) time.Time {
	if ms <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(ms).UTC()
}

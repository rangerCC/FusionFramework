package auth

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/config"
	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
	"github.com/alitrip/socialstory-server/internal/platform/jwtx"
	"github.com/alitrip/socialstory-server/internal/platform/redisx"
	"github.com/alitrip/socialstory-server/internal/platform/sms"
	"github.com/alitrip/socialstory-server/internal/util"
)

// Service implements the auth use-cases.
type Service struct {
	cfg   *config.Config
	repo  *repo
	codes *codeStore
	jwt   *jwtx.Manager
	sms   sms.Sender
}

func NewService(cfg *config.Config, pool *pgxpool.Pool, rdb *redisx.Client, ids *idgen.Snowflake, jwt *jwtx.Manager, sender sms.Sender) *Service {
	return &Service{
		cfg:   cfg,
		repo:  &repo{pool: pool, ids: ids},
		codes: &codeStore{rdb: rdb},
		jwt:   jwt,
		sms:   sender,
	}
}

// tokenPair is the issued access+refresh pair.
type tokenPair struct {
	AccessToken  string
	RefreshToken string
	ExpiresIn    int
}

// SendCode validates, rate-limits, generates and dispatches an SMS code.
func (s *Service) SendCode(ctx context.Context, phone, scene string) (resendAfter int, err error) {
	if !util.ValidPhone(phone) {
		return 0, httpx.ErrBadPhone
	}
	if err := s.codes.canSend(ctx, phone); err != nil {
		return 0, err
	}
	code := s.cfg.SMSDevCode
	if !s.cfg.SMSDevMode {
		code = util.RandCode(4)
	}
	if err := s.codes.save(ctx, scene, phone, code); err != nil {
		return 0, err
	}
	if err := s.sms.SendCode(ctx, phone, code); err != nil {
		return 0, err
	}
	return int(resendCD.Seconds()), nil
}

// LoginResult is returned to the handler for response shaping.
type LoginResult struct {
	Tokens    tokenPair
	User      *User
	IsNewUser bool
}

// LoginSMS verifies the code and logs in (creating the account if new).
func (s *Service) LoginSMS(ctx context.Context, phone, code, deviceID string) (*LoginResult, error) {
	if !util.ValidPhone(phone) {
		return nil, httpx.ErrBadPhone
	}
	if err := s.codes.verify(ctx, "login", phone, code); err != nil {
		return nil, err
	}
	u, err := s.repo.findUserByIdentity(ctx, "phone", phone)
	if err != nil {
		return nil, err
	}
	isNew := false
	if u == nil {
		nickname := "家长_" + phone[7:]
		u, err = s.repo.createUserWithIdentity(ctx, "phone", phone, nickname)
		if err != nil {
			return nil, err
		}
		isNew = true
	}
	pair, err := s.issueTokens(ctx, u.ID, deviceID)
	if err != nil {
		return nil, err
	}
	return &LoginResult{Tokens: *pair, User: u, IsNewUser: isNew}, nil
}

// Refresh rotates a refresh token, detecting replay of revoked tokens.
func (s *Service) Refresh(ctx context.Context, refreshToken, deviceID string) (*tokenPair, error) {
	hash := util.SHA256Hex(refreshToken)
	row, err := s.repo.findRefreshToken(ctx, hash)
	if err != nil {
		return nil, err
	}
	if row == nil {
		return nil, httpx.ErrRefreshInvalid
	}
	if row.Revoked {
		// Replay of an already-rotated token: revoke everything for safety.
		_ = s.repo.revokeAllForUser(ctx, row.UserID)
		return nil, httpx.ErrRefreshReplay
	}
	if time.Now().After(row.ExpiresAt) {
		return nil, httpx.ErrRefreshInvalid
	}
	// Rotate: revoke old, issue new.
	_ = s.repo.revokeRefreshToken(ctx, hash)
	return s.issueTokens(ctx, row.UserID, deviceID)
}

// Logout revokes the given refresh token.
func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	return s.repo.revokeRefreshToken(ctx, util.SHA256Hex(refreshToken))
}

func (s *Service) issueTokens(ctx context.Context, userID int64, deviceID string) (*tokenPair, error) {
	access, err := s.jwt.Issue(userID)
	if err != nil {
		return nil, err
	}
	refresh := util.RandToken("rt_", 32)
	exp := time.Now().Add(s.cfg.RefreshTokenTTL)
	if err := s.repo.saveRefreshToken(ctx, userID, util.SHA256Hex(refresh), deviceID, exp); err != nil {
		return nil, err
	}
	return &tokenPair{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int(s.cfg.AccessTokenTTL.Seconds()),
	}, nil
}

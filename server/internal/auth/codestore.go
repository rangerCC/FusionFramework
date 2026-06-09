package auth

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/redisx"
	"github.com/alitrip/socialstory-server/internal/util"
)

// codeStore manages SMS codes and send-rate limits in Redis.
type codeStore struct {
	rdb *redisx.Client
}

const (
	codeTTL     = 5 * time.Minute
	resendCD    = 60 * time.Second
	maxAttempts = 5
	dailyMax    = 10
)

func smsKey(scene, phone string) string     { return fmt.Sprintf("sms:%s:%s", scene, phone) }
func smsAttempt(scene, phone string) string { return fmt.Sprintf("sms:try:%s:%s", scene, phone) }
func smsCDKey(phone string) string          { return "sms:cd:" + phone }
func smsDailyKey(phone string) string       { return "sms:daily:" + phone }

// canSend enforces the 60s cooldown and daily cap. Returns nil if allowed.
func (s *codeStore) canSend(ctx context.Context, phone string) error {
	if exists, _ := s.rdb.Exists(ctx, smsCDKey(phone)); exists {
		return httpx.ErrSMSTooFrequent
	}
	// Daily counter (incremented on save).
	cntStr, err := s.rdb.Get(ctx, smsDailyKey(phone))
	if err == nil {
		if n, _ := strconv.Atoi(cntStr); n >= dailyMax {
			return httpx.ErrSMSTooFrequent
		}
	}
	return nil
}

// save stores the (hashed) code, sets cooldown and bumps the daily counter.
func (s *codeStore) save(ctx context.Context, scene, phone, code string) error {
	if err := s.rdb.Set(ctx, smsKey(scene, phone), util.SHA256Hex(code), codeTTL); err != nil {
		return err
	}
	_ = s.rdb.Del(ctx, smsAttempt(scene, phone))
	_ = s.rdb.Set(ctx, smsCDKey(phone), "1", resendCD)
	// Daily counter resets at end of day; approximate with 24h TTL.
	_, _ = s.rdb.Incr(ctx, smsDailyKey(phone), 24*time.Hour)
	return nil
}

// verify checks a submitted code; consumes it on success.
func (s *codeStore) verify(ctx context.Context, scene, phone, code string) error {
	stored, err := s.rdb.Get(ctx, smsKey(scene, phone))
	if redisx.IsNil(err) {
		return httpx.ErrCodeExpired
	}
	if err != nil {
		return err
	}
	// Attempt limit.
	attempts, _ := s.rdb.Incr(ctx, smsAttempt(scene, phone), codeTTL)
	if attempts > maxAttempts {
		_ = s.rdb.Del(ctx, smsKey(scene, phone))
		return httpx.ErrCodeTooMany
	}
	if stored != util.SHA256Hex(code) {
		return httpx.ErrBadCode
	}
	// Success: consume.
	_ = s.rdb.Del(ctx, smsKey(scene, phone))
	_ = s.rdb.Del(ctx, smsAttempt(scene, phone))
	return nil
}

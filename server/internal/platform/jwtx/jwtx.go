package jwtx

import (
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Manager signs and verifies access tokens (HS256).
type Manager struct {
	secret []byte
	ttl    time.Duration
}

func New(secret string, ttl time.Duration) *Manager {
	return &Manager{secret: []byte(secret), ttl: ttl}
}

// Issue returns a signed access token for the given user id.
func (m *Manager) Issue(userID int64) (string, error) {
	now := time.Now()
	claims := jwt.RegisteredClaims{
		Subject:   strconv.FormatInt(userID, 10),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(m.ttl)),
		ID:        randID(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString(m.secret)
}

// Verify parses and validates a token, returning the user id.
func (m *Manager) Verify(tokenStr string) (int64, error) {
	claims := &jwt.RegisteredClaims{}
	_, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return m.secret, nil
	})
	if err != nil {
		return 0, err
	}
	return strconv.ParseInt(claims.Subject, 10, 64)
}

func randID() string {
	return strconv.FormatInt(time.Now().UnixNano(), 36)
}

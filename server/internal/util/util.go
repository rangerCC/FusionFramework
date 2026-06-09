package util

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"regexp"
	"time"
)

var phoneRe = regexp.MustCompile(`^1[3-9]\d{9}$`)

// ValidPhone reports whether s is a mainland-China mobile number.
func ValidPhone(s string) bool { return phoneRe.MatchString(s) }

// MaskPhone turns 13800138000 into 138****8000.
func MaskPhone(s string) string {
	if len(s) != 11 {
		return s
	}
	return s[:3] + "****" + s[7:]
}

// SHA256Hex returns the hex sha256 of s.
func SHA256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

// RandToken returns a url-safe random token with the given prefix.
func RandToken(prefix string, nbytes int) string {
	b := make([]byte, nbytes)
	_, _ = rand.Read(b)
	return prefix + base64.RawURLEncoding.EncodeToString(b)
}

// RandCode returns an n-digit numeric code.
func RandCode(n int) string {
	const digits = "0123456789"
	b := make([]byte, n)
	_, _ = rand.Read(b)
	for i := range b {
		b[i] = digits[int(b[i])%len(digits)]
	}
	return string(b)
}

// CurrentPeriod returns the YYYY-MM period in the given location.
func CurrentPeriod(loc *time.Location) string {
	return time.Now().In(loc).Format("2006-01")
}

package oss

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// maxAvatarBytes caps the direct-upload size so a client can't push an
// arbitrarily large object with a valid policy.
const maxAvatarBytes = 5 * 1024 * 1024 // 5 MiB

// UploadGrant is the direct-upload credential returned to the client.
type UploadGrant struct {
	UploadURL  string            `json:"upload_url"`
	ObjectKey  string            `json:"object_key"`
	FormFields map[string]string `json:"form_fields"`
	PublicURL  string            `json:"public_url"`
	ExpiresIn  int               `json:"expires_in"`
}

// Signer issues OSS direct-upload credentials (PostObject policy).
type Signer interface {
	AvatarUploadGrant(userPublicID string) (*UploadGrant, error)
}

// AliyunSigner builds OSS PostObject policies. This is a scaffold: fill in the
// policy/signature computation per Aliyun OSS PostObject docs.
type AliyunSigner struct {
	Endpoint   string
	Bucket     string
	AccessKey  string
	Secret     string
	PublicHost string
}

func (s AliyunSigner) AvatarUploadGrant(userPublicID string) (*UploadGrant, error) {
	if s.Bucket == "" || s.AccessKey == "" {
		return nil, fmt.Errorf("oss not configured")
	}
	key := fmt.Sprintf("avatar/%s/%s.jpg", userPublicID, idgen.PublicID("img"))
	expire := time.Now().Add(10 * time.Minute)

	// Build the PostObject policy. OSS validates the form POST against these
	// conditions, so each non-signature field the client sends must be covered
	// here or OSS rejects the upload. expiration MUST be UTC ISO8601 with ms —
	// a local-zone timestamp makes OSS treat the policy as already expired.
	policyDoc := map[string]any{
		"expiration": expire.UTC().Format("2006-01-02T15:04:05.000Z"),
		"conditions": []any{
			map[string]string{"bucket": s.Bucket},
			[]any{"eq", "$key", key},
			[]any{"content-length-range", 0, maxAvatarBytes},
			[]any{"eq", "$success_action_status", "200"},
		},
	}
	raw, err := json.Marshal(policyDoc)
	if err != nil {
		return nil, fmt.Errorf("oss: marshal policy: %w", err)
	}
	policyB64 := base64.StdEncoding.EncodeToString(raw)

	// PostObject signature: base64(HMAC-SHA1(AccessKeySecret, base64(policy))).
	mac := hmac.New(sha1.New, []byte(s.Secret))
	mac.Write([]byte(policyB64))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	fields := map[string]string{
		"key":                   key,
		"OSSAccessKeyId":        s.AccessKey,
		"policy":                policyB64,
		"signature":             signature,
		"success_action_status": "200",
	}
	public := fmt.Sprintf("%s/%s", s.PublicHost, key)
	if s.PublicHost == "" {
		public = fmt.Sprintf("https://%s.%s/%s", s.Bucket, s.Endpoint, key)
	}
	return &UploadGrant{
		UploadURL:  fmt.Sprintf("https://%s.%s", s.Bucket, s.Endpoint),
		ObjectKey:  key,
		FormFields: fields,
		PublicURL:  public,
		ExpiresIn:  int(time.Until(expire).Seconds()),
	}, nil
}

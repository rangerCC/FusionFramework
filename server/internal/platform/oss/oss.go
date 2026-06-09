package oss

import (
	"fmt"
	"time"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

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

	// TODO: build a real PostObject policy document, base64 it, and HMAC-SHA1
	// sign with Secret. Fields below illustrate the shape the client expects.
	//   policyDoc := {"expiration": expire, "conditions":[["eq","$key",key], ...]}
	//   policy := base64(policyDoc); signature := base64(hmacSHA1(Secret, policy))
	fields := map[string]string{
		"key":                   key,
		"OSSAccessKeyId":        s.AccessKey,
		"policy":                "<base64-policy>",
		"signature":             "<signature>",
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

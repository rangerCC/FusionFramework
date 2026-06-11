package oss

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
)

func TestAvatarUploadGrant_NotConfigured(t *testing.T) {
	s := AliyunSigner{} // no bucket / access key
	if _, err := s.AvatarUploadGrant("u_123"); err == nil {
		t.Fatal("expected error when OSS is not configured")
	}
}

func TestAvatarUploadGrant_SignatureSelfConsistent(t *testing.T) {
	s := AliyunSigner{
		Endpoint:   "oss-cn-hangzhou.aliyuncs.com",
		Bucket:     "socialstory-prod",
		AccessKey:  "ak-test",
		Secret:     "sk-test",
		PublicHost: "https://cdn.example.com",
	}
	g, err := s.AvatarUploadGrant("u_123")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Recompute the signature from the returned policy and confirm it matches.
	policyB64 := g.FormFields["policy"]
	if policyB64 == "" || policyB64 == "<base64-policy>" {
		t.Fatalf("policy not populated: %q", policyB64)
	}
	mac := hmac.New(sha1.New, []byte(s.Secret))
	mac.Write([]byte(policyB64))
	want := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	if g.FormFields["signature"] != want {
		t.Fatalf("signature mismatch: got %q want %q", g.FormFields["signature"], want)
	}

	// The policy must decode to JSON with an expiration and conditions binding $key.
	rawPolicy, err := base64.StdEncoding.DecodeString(policyB64)
	if err != nil {
		t.Fatalf("policy not valid base64: %v", err)
	}
	var doc struct {
		Expiration string `json:"expiration"`
		Conditions []any  `json:"conditions"`
	}
	if err := json.Unmarshal(rawPolicy, &doc); err != nil {
		t.Fatalf("policy not valid json: %v", err)
	}
	if !strings.HasSuffix(doc.Expiration, "Z") {
		t.Fatalf("expiration must be UTC (end with Z): %q", doc.Expiration)
	}
	if len(doc.Conditions) == 0 {
		t.Fatal("policy conditions must not be empty")
	}

	// Form fields and key must line up with the conditions the policy signs.
	if g.FormFields["key"] != g.ObjectKey {
		t.Fatalf("form key %q != object key %q", g.FormFields["key"], g.ObjectKey)
	}
	if g.FormFields["OSSAccessKeyId"] != s.AccessKey {
		t.Fatalf("OSSAccessKeyId mismatch: %q", g.FormFields["OSSAccessKeyId"])
	}
	if !strings.HasPrefix(g.ObjectKey, "avatar/u_123/") {
		t.Fatalf("object key prefix unexpected: %q", g.ObjectKey)
	}
	if g.PublicURL != s.PublicHost+"/"+g.ObjectKey {
		t.Fatalf("public url unexpected: %q", g.PublicURL)
	}
}

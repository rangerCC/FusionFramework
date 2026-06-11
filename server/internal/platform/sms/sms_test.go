package sms

import (
	"context"
	"testing"
)

func TestAliyunSender_NotConfigured(t *testing.T) {
	cases := []struct {
		name   string
		sender *AliyunSender
	}{
		{"empty", &AliyunSender{}},
		{"missing template", &AliyunSender{AccessKey: "ak", SignName: "签名"}},
		{"missing sign", &AliyunSender{AccessKey: "ak", TemplateCode: "SMS_1"}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if err := c.sender.SendCode(context.Background(), "13800138000", "1234"); err == nil {
				t.Fatal("expected error when sms is not fully configured")
			}
		})
	}
}

func TestDevSender_AlwaysOK(t *testing.T) {
	if err := (DevSender{}).SendCode(context.Background(), "13800138000", "1234"); err != nil {
		t.Fatalf("dev sender should not fail: %v", err)
	}
}

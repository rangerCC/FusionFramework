package sms

import (
	"context"
	"fmt"
	"log"
)

// Sender sends SMS verification codes. Swap the implementation for a real
// provider (Aliyun) in production via config.
type Sender interface {
	SendCode(ctx context.Context, phone, code string) error
}

// DevSender logs the code instead of sending it. Used when SMS_DEV_MODE=true.
type DevSender struct{}

func (DevSender) SendCode(ctx context.Context, phone, code string) error {
	log.Printf("[sms-dev] code for %s = %s", phone, code)
	return nil
}

// AliyunSender is a placeholder for the Aliyun Dysmsapi integration.
// Wire up github.com/aliyun/alibaba-cloud-sdk-go (Dysmsapi) here: build a
// SendSmsRequest with SignName/TemplateCode and TemplateParam {"code": code}.
type AliyunSender struct {
	AccessKey    string
	AccessSecret string
	SignName     string
	TemplateCode string
}

func (s AliyunSender) SendCode(ctx context.Context, phone, code string) error {
	// TODO: integrate Aliyun Dysmsapi SDK. Intentionally returns an error until
	// configured so misconfiguration is loud rather than silently dropping codes.
	if s.AccessKey == "" || s.TemplateCode == "" {
		return fmt.Errorf("aliyun sms not configured")
	}
	// Pseudocode of the real call:
	//   client := dysmsapi.NewClientWithAccessKey("cn-hangzhou", s.AccessKey, s.AccessSecret)
	//   req := dysmsapi.CreateSendSmsRequest()
	//   req.PhoneNumbers = phone; req.SignName = s.SignName; req.TemplateCode = s.TemplateCode
	//   req.TemplateParam = fmt.Sprintf(`{"code":"%s"}`, code)
	//   _, err := client.SendSms(req); return err
	return fmt.Errorf("aliyun sms send not implemented; enable SMS_DEV_MODE for local dev")
}

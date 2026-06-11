package sms

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"

	openapi "github.com/alibabacloud-go/darabonba-openapi/v2/client"
	dysmsapi "github.com/alibabacloud-go/dysmsapi-20170525/v3/client"
	"github.com/alibabacloud-go/tea/tea"
	util "github.com/alibabacloud-go/tea-utils/v2/service"
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

// smsEndpoint is the nationwide public endpoint. Inside an Aliyun VPC you may
// switch to the internal endpoint (dysmsapi-vpc.cn-<region>.aliyuncs.com) to
// save egress traffic; the public one works everywhere.
const smsEndpoint = "dysmsapi.aliyuncs.com"

// AliyunSender sends codes via Aliyun Dysmsapi (V2/V3 OpenAPI SDK).
type AliyunSender struct {
	AccessKey    string
	AccessSecret string
	SignName     string
	TemplateCode string

	once   sync.Once
	client *dysmsapi.Client
	initErr error
}

// init lazily builds and caches the OpenAPI client. The SDK client is safe for
// concurrent reuse, so we build it once.
func (s *AliyunSender) init() (*dysmsapi.Client, error) {
	s.once.Do(func() {
		cfg := &openapi.Config{
			AccessKeyId:     tea.String(s.AccessKey),
			AccessKeySecret: tea.String(s.AccessSecret),
			Endpoint:        tea.String(smsEndpoint),
		}
		s.client, s.initErr = dysmsapi.NewClient(cfg)
	})
	return s.client, s.initErr
}

func (s *AliyunSender) SendCode(ctx context.Context, phone, code string) error {
	if s.AccessKey == "" || s.TemplateCode == "" || s.SignName == "" {
		return fmt.Errorf("aliyun sms not configured")
	}
	cli, err := s.init()
	if err != nil {
		return fmt.Errorf("aliyun sms client: %w", err)
	}

	param, err := json.Marshal(map[string]string{"code": code})
	if err != nil {
		return fmt.Errorf("aliyun sms marshal param: %w", err)
	}
	req := &dysmsapi.SendSmsRequest{
		PhoneNumbers:  tea.String(phone),
		SignName:      tea.String(s.SignName),
		TemplateCode:  tea.String(s.TemplateCode),
		TemplateParam: tea.String(string(param)),
	}

	resp, err := cli.SendSmsWithOptions(req, &util.RuntimeOptions{})
	if err != nil {
		return fmt.Errorf("aliyun sms send: %w", err)
	}
	// HTTP 200 with a non-OK business code is still a failure (unapproved sign,
	// throttling via isv.BUSINESS_LIMIT_CONTROL, bad template, etc). err is nil
	// in that case, so the code must be checked explicitly.
	if resp == nil || resp.Body == nil || tea.StringValue(resp.Body.Code) != "OK" {
		var bizCode, msg string
		if resp != nil && resp.Body != nil {
			bizCode = tea.StringValue(resp.Body.Code)
			msg = tea.StringValue(resp.Body.Message)
		}
		return fmt.Errorf("aliyun sms rejected: code=%s message=%s", bizCode, msg)
	}
	return nil
}

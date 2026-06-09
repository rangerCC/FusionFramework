package appstore

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// TransactionInfo is the decoded JWSTransaction payload (subset we use).
type TransactionInfo struct {
	OriginalTransactionID string
	TransactionID         string
	ProductID             string
	ExpiresDate           time.Time
	AppAccountToken       string
	Environment           string // Production | Sandbox
}

// RenewalInfo is the decoded JWSRenewalInfo payload (subset).
type RenewalInfo struct {
	AutoRenewStatus bool
	ProductID       string
}

// NotificationPayload is the decoded App Store Server Notification V2.
type NotificationPayload struct {
	NotificationType string
	Subtype          string
	NotificationUUID string
	SignedDate       time.Time
	Environment      string
	Transaction      *TransactionInfo
	Renewal          *RenewalInfo
}

// Verifier validates Apple signatures and queries the App Store Server API.
type Verifier interface {
	// ParseNotification verifies the signed payload and decodes it.
	ParseNotification(signedPayload string) (*NotificationPayload, error)
	// LookupTransaction fetches & verifies a single transaction by id.
	LookupTransaction(transactionID string) (*TransactionInfo, error)
}

// DefaultVerifier is a scaffold. The JWS signature verification (x5c chain
// against Apple root CA) MUST be implemented before production use — see notes.
type DefaultVerifier struct {
	BundleID       string
	IssuerID       string
	KeyID          string
	PrivateKeyPath string
}

// decodeJWSPayload base64url-decodes the middle segment WITHOUT verifying the
// signature. Used only as the decode step; real verification is a TODO below.
func decodeJWSPayload(jws string, out interface{}) error {
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		return fmt.Errorf("invalid jws")
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return fmt.Errorf("decode jws payload: %w", err)
	}
	return json.Unmarshal(payload, out)
}

// ParseNotification decodes the V2 notification.
//
// PRODUCTION TODO: verify the JWS signature for signedPayload and each nested
// signedTransactionInfo / signedRenewalInfo by validating the x5c certificate
// chain up to Apple's root CA and checking the signature. Without this, payloads
// are untrusted. Consider github.com/awa/go-iap or apple's app-store-server-library.
func (v *DefaultVerifier) ParseNotification(signedPayload string) (*NotificationPayload, error) {
	var envelope struct {
		NotificationType string `json:"notificationType"`
		Subtype          string `json:"subtype"`
		NotificationUUID string `json:"notificationUUID"`
		Data             struct {
			Environment           string `json:"environment"`
			SignedTransactionInfo string `json:"signedTransactionInfo"`
			SignedRenewalInfo     string `json:"signedRenewalInfo"`
		} `json:"data"`
	}
	if err := decodeJWSPayload(signedPayload, &envelope); err != nil {
		return nil, err
	}
	out := &NotificationPayload{
		NotificationType: envelope.NotificationType,
		Subtype:          envelope.Subtype,
		NotificationUUID: envelope.NotificationUUID,
		Environment:      envelope.Data.Environment,
		SignedDate:       time.Now(),
	}
	if envelope.Data.SignedTransactionInfo != "" {
		if tx, err := decodeTransaction(envelope.Data.SignedTransactionInfo); err == nil {
			out.Transaction = tx
		}
	}
	if envelope.Data.SignedRenewalInfo != "" {
		var r struct {
			AutoRenewStatus int    `json:"autoRenewStatus"`
			ProductID       string `json:"autoRenewProductId"`
		}
		if err := decodeJWSPayload(envelope.Data.SignedRenewalInfo, &r); err == nil {
			out.Renewal = &RenewalInfo{AutoRenewStatus: r.AutoRenewStatus == 1, ProductID: r.ProductID}
		}
	}
	return out, nil
}

func decodeTransaction(jws string) (*TransactionInfo, error) {
	var t struct {
		OriginalTransactionID string `json:"originalTransactionId"`
		TransactionID         string `json:"transactionId"`
		ProductID             string `json:"productId"`
		ExpiresDateMs         int64  `json:"expiresDate"`
		AppAccountToken       string `json:"appAccountToken"`
		Environment           string `json:"environment"`
	}
	if err := decodeJWSPayload(jws, &t); err != nil {
		return nil, err
	}
	info := &TransactionInfo{
		OriginalTransactionID: t.OriginalTransactionID,
		TransactionID:         t.TransactionID,
		ProductID:             t.ProductID,
		AppAccountToken:       t.AppAccountToken,
		Environment:           t.Environment,
	}
	if t.ExpiresDateMs > 0 {
		info.ExpiresDate = time.UnixMilli(t.ExpiresDateMs).UTC()
	}
	return info, nil
}

// LookupTransaction queries the App Store Server API.
//
// PRODUCTION TODO: build a JWT with ES256 signed by the .p8 key (KeyID, IssuerID,
// audience "appstoreconnect-v1"), call GET https://api.storekit.itunes.apple.com
// /inApps/v1/transactions/{id}, then verify & decode the returned JWS.
func (v *DefaultVerifier) LookupTransaction(transactionID string) (*TransactionInfo, error) {
	return nil, fmt.Errorf("LookupTransaction not implemented; integrate App Store Server API")
}

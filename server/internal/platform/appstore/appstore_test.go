package appstore

import (
	"testing"
	"time"

	iapapi "github.com/awa/go-iap/appstore/api"
)

func TestInit_MissingKeyFailsLoudly(t *testing.T) {
	v := &DefaultVerifier{PrivateKeyPath: "/nonexistent/AuthKey.p8"}
	if _, err := v.LookupTransaction("tx_1"); err == nil {
		t.Fatal("expected error when .p8 key is missing")
	}
	// ParseNotification should also surface the init error.
	if _, err := v.ParseNotification("a.b.c"); err == nil {
		t.Fatal("expected init error to propagate to ParseNotification")
	}
}

func TestMapTransaction(t *testing.T) {
	expMs := int64(1700000000000)
	tx := &iapapi.JWSTransaction{
		OriginalTransactionId: "orig_1",
		TransactionID:         "tx_1",
		ProductID:             "com.app.sub.monthly",
		AppAccountToken:       "tok_1",
		Environment:           iapapi.Sandbox,
		ExpiresDate:           expMs,
	}
	got := mapTransaction(tx)
	if got.OriginalTransactionID != "orig_1" || got.TransactionID != "tx_1" {
		t.Fatalf("ids not mapped: %+v", got)
	}
	if got.ProductID != "com.app.sub.monthly" || got.Environment != "Sandbox" {
		t.Fatalf("product/env not mapped: %+v", got)
	}
	if !got.ExpiresDate.Equal(time.UnixMilli(expMs).UTC()) {
		t.Fatalf("expires date not mapped: %v", got.ExpiresDate)
	}
}

func TestMsToTime(t *testing.T) {
	if !msToTime(0).IsZero() {
		t.Fatal("0 ms should map to zero time")
	}
	if !msToTime(-1).IsZero() {
		t.Fatal("negative ms should map to zero time")
	}
	ms := int64(1700000000000)
	got := msToTime(ms)
	if got.Location() != time.UTC {
		t.Fatalf("expected UTC, got %v", got.Location())
	}
}

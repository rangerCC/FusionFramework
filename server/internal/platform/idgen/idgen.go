package idgen

import (
	"crypto/rand"
	"encoding/base32"
	"strings"
	"sync"
	"time"
)

// Snowflake-ish 63-bit ID generator: 41-bit ms timestamp | 10-bit node | 12-bit seq.
// Single-process safe. For multi-instance deploys, give each instance a distinct node.
type Snowflake struct {
	mu     sync.Mutex
	epoch  int64
	node   int64
	seq    int64
	lastMs int64
}

const (
	nodeBits = 10
	seqBits  = 12
	maxSeq   = (1 << seqBits) - 1
)

// NewSnowflake creates a generator. node must be 0..1023.
func NewSnowflake(node int64) *Snowflake {
	return &Snowflake{
		epoch: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC).UnixMilli(),
		node:  node & ((1 << nodeBits) - 1),
	}
}

// Next returns the next unique int64 id.
func (s *Snowflake) Next() int64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UnixMilli()
	if now == s.lastMs {
		s.seq = (s.seq + 1) & maxSeq
		if s.seq == 0 {
			// sequence overflow within the same ms: spin to next ms
			for now <= s.lastMs {
				now = time.Now().UnixMilli()
			}
		}
	} else {
		s.seq = 0
	}
	s.lastMs = now
	return ((now - s.epoch) << (nodeBits + seqBits)) | (s.node << seqBits) | s.seq
}

var b32 = base32.NewEncoding("0123456789abcdefghijklmnopqrstuv").WithPadding(base32.NoPadding)

// PublicID builds a prefixed, opaque public identifier, e.g. "u_" + random.
// It does not encode the internal id, so sequence is not leaked.
func PublicID(prefix string) string {
	b := make([]byte, 10)
	_, _ = rand.Read(b)
	return prefix + "_" + strings.ToLower(b32.EncodeToString(b))
}

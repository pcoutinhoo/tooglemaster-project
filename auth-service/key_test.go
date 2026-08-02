package main

import (
	"strings"
	"testing"
)

func TestGenerateAPIKey_HasCorrectPrefixAndLength(t *testing.T) {
	key, err := generateAPIKey()
	if err != nil {
		t.Fatalf("erro inesperado ao gerar chave: %v", err)
	}

	if !strings.HasPrefix(key, "tm_key_") {
		t.Errorf("esperava prefixo 'tm_key_', obteve: %s", key)
	}

	expectedLen := 71
	if len(key) != expectedLen {
		t.Errorf("esperava chave com %d caracteres, obteve %d: %s", expectedLen, len(key), key)
	}
}

func TestGenerateAPIKey_GeneratesUniqueKeys(t *testing.T) {
	key1, _ := generateAPIKey()
	key2, _ := generateAPIKey()

	if key1 == key2 {
		t.Error("duas chamadas a generateAPIKey geraram a mesma chave — sem aleatoriedade real")
	}
}

func TestHashAPIKey_IsDeterministic(t *testing.T) {
	key := "tm_key_exemplo123"
	hash1 := hashAPIKey(key)
	hash2 := hashAPIKey(key)

	if hash1 != hash2 {
		t.Errorf("hash da mesma chave deveria ser igual, obteve %s e %s", hash1, hash2)
	}
}

func TestHashAPIKey_HasCorrectLength(t *testing.T) {
	hash := hashAPIKey("qualquer-chave")

	if len(hash) != 64 {
		t.Errorf("esperava hash com 64 caracteres (SHA-256 hex), obteve %d", len(hash))
	}
}

func TestHashAPIKey_DifferentKeysProduceDifferentHashes(t *testing.T) {
	hash1 := hashAPIKey("chave-a")
	hash2 := hashAPIKey("chave-b")

	if hash1 == hash2 {
		t.Error("chaves diferentes produziram o mesmo hash")
	}
}

package main

import "testing"

func TestGetDeterministicBucket_Consistency(t *testing.T) {
	input := "user_42nova_ui"
	first := getDeterministicBucket(input)
	second := getDeterministicBucket(input)

	if first != second {
		t.Errorf("esperava bucket consistente, obteve %d na 1a chamada e %d na 2a", first, second)
	}
}

func TestGetDeterministicBucket_Range(t *testing.T) {
	inputs := []string{"user_1flag_a", "user_2flag_b", "abc123", ""}

	for _, in := range inputs {
		bucket := getDeterministicBucket(in)
		if bucket < 0 || bucket > 99 {
			t.Errorf("bucket fora do intervalo 0-99 para input %q: %d", in, bucket)
		}
	}
}

func TestGetDeterministicBucket_Distribution(t *testing.T) {
	b1 := getDeterministicBucket("user_1flag_x")
	b2 := getDeterministicBucket("user_2flag_x")

	if b1 == b2 {
		t.Logf("aviso: user_1 e user_2 caíram no mesmo bucket (%d) — pode ser coincidência, mas vale checar", b1)
	}
}

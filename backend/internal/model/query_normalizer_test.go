package model

import (
	"testing"
)

func TestGenerateSearchQueryVariants(t *testing.T) {
	cases := []struct {
		input    string
		expected []string
	}{
		{
			input:    "t.i.t.l.e.",
			expected: []string{"t.i.t.l.e.", "title", "t i t l e"},
		},
		{
			input:    "s.h.i.e.l.d.",
			expected: []string{"s.h.i.e.l.d.", "shield", "s h i e l d"},
		},
		{
			input:    "Fast & Furious 9",
			expected: []string{"Fast & Furious 9", "Fast and Furious 9"},
		},
		{
			input:    "Amélie",
			expected: []string{"Amélie", "Amelie"},
		},
	}

	for _, tc := range cases {
		variants := GenerateSearchQueryVariants(tc.input)
		for _, exp := range tc.expected {
			found := false
			for _, v := range variants {
				if v == exp {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("For input %q, expected variant %q in %v", tc.input, exp, variants)
			}
		}
	}
}

func TestCleanForFuzzyMatch(t *testing.T) {
	if CleanForFuzzyMatch("T.I.T.L.E.") != "title" {
		t.Errorf("Expected 'title', got %q", CleanForFuzzyMatch("T.I.T.L.E."))
	}
	if CleanForFuzzyMatch("t.i.t.l.e.") != "title" {
		t.Errorf("Expected 'title', got %q", CleanForFuzzyMatch("t.i.t.l.e."))
	}
	if CleanForFuzzyMatch("Agents of S.H.I.E.L.D.") != "agents of shield" {
		t.Errorf("Expected 'agents of shield', got %q", CleanForFuzzyMatch("Agents of S.H.I.E.L.D."))
	}
}

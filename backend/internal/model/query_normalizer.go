package model

import (
	"strings"
	"unicode"
)

// GenerateSearchQueryVariants takes an input title/query and produces clean,
// normalized variations to handle dots (e.g. t.i.t.l.e. -> title), acronyms (S.H.I.E.L.D.),
// strange punctuation/symbols, and diacritics.
func GenerateSearchQueryVariants(q string) []string {
	trimmed := strings.TrimSpace(q)
	if trimmed == "" {
		return nil
	}

	seen := make(map[string]bool)
	var list []string

	add := func(s string) {
		s = strings.TrimSpace(s)
		if s == "" {
			return
		}
		lower := strings.ToLower(s)
		if !seen[lower] {
			seen[lower] = true
			list = append(list, s)
		}
	}

	// 1. Raw query as entered
	add(trimmed)

	// 2. Dot-removed (e.g. "t.i.t.l.e." -> "title", "s.h.i.e.l.d." -> "shield")
	if strings.Contains(trimmed, ".") {
		add(strings.ReplaceAll(trimmed, ".", ""))
		add(strings.ReplaceAll(trimmed, ".", " "))
	}

	// 3. Punctuation and symbols stripped / replaced
	replacer := strings.NewReplacer(
		"&", "and",
		"-", " ",
		":", " ",
		"_", " ",
		"/", " ",
		"\\", " ",
		"'", "",
		"\"", "",
		"!", "",
		"?", "",
		"(", " ",
		")", " ",
		"[", " ",
		"]", " ",
		"~", " ",
		"*", " ",
		"+", " ",
	)
	cleaned := strings.Join(strings.Fields(replacer.Replace(trimmed)), " ")
	add(cleaned)

	// 4. Diacritics / Accent folding (e.g. "Amélie" -> "Amelie", "Pokémon" -> "Pokemon")
	folded := FoldDiacritics(cleaned)
	if folded != cleaned {
		add(folded)
	}

	foldedRaw := FoldDiacritics(trimmed)
	if foldedRaw != trimmed {
		add(foldedRaw)
	}

	return list
}

// FoldDiacritics converts accented Latin characters to basic ASCII
func FoldDiacritics(s string) string {
	replacer := strings.NewReplacer(
		"é", "e", "è", "e", "ê", "e", "ë", "e",
		"à", "a", "á", "a", "â", "a", "ã", "a", "ä", "a", "å", "a",
		"ì", "i", "í", "i", "î", "i", "ï", "i",
		"ò", "o", "ó", "o", "ô", "o", "õ", "o", "ö", "o", "ø", "o",
		"ù", "u", "ú", "u", "û", "u", "ü", "u",
		"ý", "y", "ÿ", "y",
		"ñ", "n", "ç", "c",
		"É", "E", "È", "E", "Ê", "E", "Ë", "E",
		"À", "A", "Á", "A", "Â", "A", "Ã", "A", "Ä", "A", "Å", "A",
		"Ì", "I", "Í", "I", "Î", "I", "Ï", "I",
		"Ò", "O", "Ó", "O", "Ô", "O", "Õ", "O", "Ö", "O", "Ø", "O",
		"Ù", "U", "Ú", "U", "Û", "U", "Ü", "U",
		"Ý", "Y", "Ñ", "N", "Ç", "C",
	)
	return replacer.Replace(s)
}

// CleanForFuzzyMatch strips all non-alphanumeric runes, removes dots, and folds diacritics
// so that "T.I.T.L.E.", "title", and "t.i.t.l.e." all reduce to "title".
func CleanForFuzzyMatch(s string) string {
	s = FoldDiacritics(strings.ToLower(s))
	var b strings.Builder
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || r == ' ' {
			b.WriteRune(r)
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}

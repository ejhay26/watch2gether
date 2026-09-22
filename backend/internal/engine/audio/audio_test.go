package audio

import "testing"

func TestAudioEngineFormatting(t *testing.T) {
	ae := NewAudioEngine()

	lbl1 := ae.FormatTrackLabel(0, "en", "", "2.0")
	if lbl1 != "Track 1: English [2.0]" {
		t.Errorf("Unexpected formatted label: %s", lbl1)
	}

	lbl2 := ae.FormatTrackLabel(1, "es", "Spanish (Latin America)", "5.1")
	if lbl2 != "Spanish (Latin America)" {
		t.Errorf("Expected explicit title to be preserved, got %s", lbl2)
	}

	lbl3 := ae.FormatTrackLabel(2, "ja", "Track", "Stereo")
	if lbl3 != "Track 3: Japanese [Stereo]" {
		t.Errorf("Expected generic 'Track' to be rewritten with language, got %s", lbl3)
	}
}

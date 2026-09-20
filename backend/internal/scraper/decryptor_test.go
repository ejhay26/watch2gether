package scraper

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"testing"
)

func pkcs7Pad(data []byte, blockSize int) []byte {
	padding := blockSize - len(data)%blockSize
	padtext := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(data, padtext...)
}

func encryptAESCBC(plaintext, key, iv []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	padded := pkcs7Pad(plaintext, aes.BlockSize)
	ciphertext := make([]byte, len(padded))
	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(ciphertext, padded)
	return ciphertext, nil
}

func TestAESCBCDecrypt(t *testing.T) {
	key := make([]byte, 32)
	iv := make([]byte, 16)
	_, _ = rand.Read(key)
	_, _ = rand.Read(iv)

	original := []byte("https://stream.example.com/hls/master.m3u8")
	cipher, err := encryptAESCBC(original, key, iv)
	if err != nil {
		t.Fatalf("Failed to encrypt: %v", err)
	}

	decrypted, err := AESCBCDecrypt(cipher, key, iv)
	if err != nil {
		t.Fatalf("Failed to decrypt: %v", err)
	}

	if !bytes.Equal(decrypted, original) {
		t.Fatalf("Decrypted mismatch: got %s, want %s", string(decrypted), string(original))
	}
}

func TestPKCS7UnpadInvalid(t *testing.T) {
	// Empty data
	_, err := PKCS7Unpad([]byte{})
	if err == nil {
		t.Errorf("Expected error for empty data")
	}

	// Bad padding length
	badPadding := []byte{1, 2, 3, 10}
	_, err = PKCS7Unpad(badPadding)
	if err == nil {
		t.Errorf("Expected error for bad padding length")
	}
}

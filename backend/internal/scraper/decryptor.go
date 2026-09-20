package scraper

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/md5"
	"encoding/base64"
	"errors"
	"fmt"
)

// PKCS7Unpad strips PKCS#7 padding from decrypted plaintext.
func PKCS7Unpad(data []byte) ([]byte, error) {
	length := len(data)
	if length == 0 {
		return nil, errors.New("empty data for unpadding")
	}
	padding := int(data[length-1])
	if padding > length || padding == 0 {
		return nil, errors.New("invalid pkcs7 padding")
	}
	for i := length - padding; i < length; i++ {
		if data[i] != byte(padding) {
			return nil, errors.New("inconsistent pkcs7 padding bytes")
		}
	}
	return data[:length-padding], nil
}

// AESCBCDecrypt decrypts ciphertext with AES in CBC mode using given key and iv.
func AESCBCDecrypt(ciphertext, key, iv []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("aes cipher creation failed: %w", err)
	}
	if len(ciphertext) < aes.BlockSize {
		return nil, errors.New("ciphertext too short")
	}
	if len(ciphertext)%aes.BlockSize != 0 {
		return nil, errors.New("ciphertext is not a multiple of the block size")
	}
	if len(iv) != aes.BlockSize {
		return nil, fmt.Errorf("invalid iv size: expected %d, got %d", aes.BlockSize, len(iv))
	}

	mode := cipher.NewCBCDecrypter(block, iv)
	plaintext := make([]byte, len(ciphertext))
	mode.CryptBlocks(plaintext, ciphertext)

	return PKCS7Unpad(plaintext)
}

// OpenSSLKeyDerivation derives key and IV from passphrase and 8-byte salt (OpenSSL EVP_BytesToKey using MD5).
func OpenSSLKeyDerivation(passphrase, salt []byte, keyLen, ivLen int) ([]byte, []byte) {
	totalLen := keyLen + ivLen
	var concatenatedHashes []byte
	var currentHash []byte

	for len(concatenatedHashes) < totalLen {
		h := md5.New()
		if len(currentHash) > 0 {
			h.Write(currentHash)
		}
		h.Write(passphrase)
		h.Write(salt)
		currentHash = h.Sum(nil)
		concatenatedHashes = append(concatenatedHashes, currentHash...)
	}

	key := concatenatedHashes[:keyLen]
	iv := concatenatedHashes[keyLen : keyLen+ivLen]
	return key, iv
}

// OpenSSLDecrypt decrypts base64 encoded or raw "Salted__" OpenSSL encrypted string with a passphrase.
func OpenSSLDecrypt(encryptedData []byte, passphrase string) ([]byte, error) {
	var raw []byte
	if bytes.HasPrefix(encryptedData, []byte("Salted__")) {
		raw = encryptedData
	} else {
		var err error
		raw, err = base64.StdEncoding.DecodeString(string(encryptedData))
		if err != nil {
			return nil, fmt.Errorf("base64 decode error: %w", err)
		}
	}

	if len(raw) < 16 || string(raw[:8]) != "Salted__" {
		return nil, errors.New("invalid openssl ciphertext header (missing Salted__ prefix)")
	}

	salt := raw[8:16]
	ciphertext := raw[16:]

	key, iv := OpenSSLKeyDerivation([]byte(passphrase), salt, 32, 16)
	return AESCBCDecrypt(ciphertext, key, iv)
}

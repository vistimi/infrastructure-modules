package util

import "math/rand"

var letterRunes = []rune("abcdefghijklmnopqrstuvwxyz")

func RandomID(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

func AppendID(id, name string) string {
	return id + "-" + name
}

func AppendIDs(id string, names []string) []string {
	for i, name := range names {
		names[i] = id + "-" + name
	}
	return names
}

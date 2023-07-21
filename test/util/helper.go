package util

func Ptr[K any](m K) *K {
	return &m
}

func Filter[T any](ss []T, test func(T) bool) (ret []T) {
	for _, s := range ss {
		if test(s) {
			ret = append(ret, s)
		}
	}
	return
}

func Reduce[T, R any](ss []T, test func(T) R) (ret []R) {
	for _, s := range ss {
		ret = append(ret, test(s))
	}
	return
}

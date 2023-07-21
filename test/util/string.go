package util

func Format(names ...string) (s string) {
	if len(names) == 0 {
		return ""
	}
	s = names[0]
	for _, name := range names[1:] {
		s = s + "-" + name
	}
	return
}

func Appends(pre string, names []string) []string {
	for i, name := range names {
		names[i] = pre + "-" + name
	}
	return names
}
func Preppends(names []string, post string) []string {
	for i, name := range names {
		names[i] = name + "-" + post
	}
	return names
}

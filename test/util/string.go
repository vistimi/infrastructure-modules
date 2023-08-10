package util

func Format(separator string, names ...string) (s string) {
	if len(names) == 0 {
		return ""
	}
	s = names[0]
	for _, name := range names[1:] {
		if name == "" {
			continue
		}
		s = s + separator + name
	}
	return
}

func Appends(separator string, pre string, names []string) []string {
	for i, name := range names {
		if name == "" {
			continue
		}
		names[i] = pre + separator + name
	}
	return names
}
func Preppends(separator string, names []string, post string) []string {
	for i, name := range names {
		if name == "" {
			continue
		}
		names[i] = name + separator + post
	}
	return names
}

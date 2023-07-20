package util

func Append(id, name string) string {
	return id + "-" + name
}

func Appends(id string, names []string) []string {
	for i, name := range names {
		names[i] = id + "-" + name
	}
	return names
}

func Preppend(id, name string) string {
	return name + "-" + id
}

func Preppends(id string, names []string) []string {
	for i, name := range names {
		names[i] = name + "-" + id
	}
	return names
}

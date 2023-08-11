package module

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"testing"
)

func ExtractFromState(t *testing.T, microservicePath, statePath string) any {
	jsonFile, err := os.Open(fmt.Sprintf("%s/terraform.tfstate", microservicePath))
	if err != nil {
		t.Fatal(err)
	}
	defer jsonFile.Close()
	byteValue, _ := io.ReadAll(jsonFile)
	var result map[string]any
	json.Unmarshal([]byte(byteValue), &result)
	result = result["outputs"].(map[string]any)

	stateFields := strings.Split(statePath, ".")
	if len(stateFields) > 1 {
		for i := 0; i < len(stateFields)-1; i++ {
			value := stateFields[i]
			fmt.Println(value)
			if result[value] == nil {
				result = result["value"].(map[string]any)
				continue
			}
			result = result[value].(map[string]any)
		}
	}
	return result[stateFields[len(stateFields)-1]]
}

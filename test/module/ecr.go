package module_test

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/likexian/gokit/assert"

	terratest_shell "github.com/gruntwork-io/terratest/modules/shell"
)

func TestEcr(t *testing.T, accountRegion, organization, repository, branch string) {
	bashCode := fmt.Sprintf(`aws ecr list-images --repository-name %s --region %s --output text --query "imageIds[].[imageTag]" | wc -l`,
		strings.ToLower(fmt.Sprintf("%s-%s-%s", organization, repository, branch)),
		accountRegion,
	)
	command := terratest_shell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	output := strings.TrimSpace(terratest_shell.RunCommandAndGetOutput(t, command))
	ecrImagesAmount, err := strconv.Atoi(output)
	if err != nil {
		t.Fatalf("String to int conversion failed: %s", output)
	}

	assert.Equal(t, 1, ecrImagesAmount, fmt.Sprintf("No image published to repository: %v", ecrImagesAmount))
}

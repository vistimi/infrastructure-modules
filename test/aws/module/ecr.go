package module

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/likexian/gokit/assert"

	terratestShell "github.com/gruntwork-io/terratest/modules/shell"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestEcr(t *testing.T, accountRegion, organization, repository, branch string) {
	terratestStructure.RunTestStage(t, "validate_ecr", func() {

		bashCode := fmt.Sprintf(`aws ecr list-images --repository-name %s --region %s --output text --query "imageIds[].[imageTag]" | wc -l`,
			strings.ToLower(fmt.Sprintf("%s-%s-%s", organization, repository, branch)),
			accountRegion,
		)
		command := terratestShell.Command{
			Command: "bash",
			Args:    []string{"-c", bashCode},
		}
		output := strings.TrimSpace(terratestShell.RunCommandAndGetOutput(t, command))
		ecrImagesAmount, err := strconv.Atoi(output)
		if err != nil {
			t.Fatalf("String to int conversion failed: %s", output)
		}

		assert.Equal(t, 1, ecrImagesAmount, fmt.Sprintf("No image published to repository: %v", ecrImagesAmount))
	})
}

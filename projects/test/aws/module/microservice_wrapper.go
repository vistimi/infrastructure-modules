package module

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/dresspeng/infrastructure-modules/test/util"
)

var (
	AccountName   = util.GetEnvVariable("AWS_PROFILE_NAME")
	AccountId     = util.GetEnvVariable("AWS_ACCOUNT_ID")
	AccountRegion = util.GetEnvVariable("AWS_REGION_NAME")
	DomainName    = fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX"))
)

const (
	// https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html#ecs-reserved-memory
	ECSReservedMemory = 100
)

func SetupOptionsMicroserviceWrapper(t *testing.T, projectName, serviceName string) (string, string, map[string]string) {
	rand.Seed(time.Now().UnixNano())

	// global variables
	namePrefix := "vi"
	id := util.RandomID(4)
	nameSuffix := strings.ToLower(util.Format("-", util.GetEnvVariable("AWS_PROFILE_NAME"), id))
	tags := map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
		"Project": projectName,
		"Service": serviceName,
	}
	return namePrefix, nameSuffix, tags
}

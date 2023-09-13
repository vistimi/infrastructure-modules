package module

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/dresspeng/infrastructure-modules/test/util"

	testAwsModule "github.com/dresspeng/infrastructure-modules/test/aws/module"
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

func SetupMicroservice(t *testing.T, microserviceInformation testAwsModule.MicroserviceInformation, traffics []testAwsModule.Traffic) (namePrefix string, nameSuffix string, tags map[string]string, trafficsMap []map[string]any, docker map[string]any, bucketEnv map[string]any) {
	rand.Seed(time.Now().UnixNano())

	// global variables
	namePrefix = "vi"
	id := util.RandomID(4)
	nameSuffix = strings.ToLower(util.Format("-", util.GetEnvVariable("AWS_PROFILE_NAME"), id))
	tags = map[string]string{
		"TestID":  id,
		"Account": AccountName,
		"Region":  AccountRegion,
	}

	for _, traffic := range traffics {
		target := map[string]any{
			"protocol":          traffic.Target.Protocol,
			"health_check_path": microserviceInformation.HealthCheckPath,
		}
		target = util.Nil(traffic.Target.Port, target, "port")
		target = util.Nil(traffic.Target.ProtocolVersion, target, "protocol_version")
		target = util.Nil(traffic.Target.StatusCode, target, "status_code")

		listener := map[string]any{
			"protocol": traffic.Listener.Protocol,
		}
		listener = util.Nil(traffic.Listener.Port, listener, "port")
		listener = util.Nil(traffic.Listener.ProtocolVersion, listener, "protocol_version")

		trafficsMap = append(trafficsMap, map[string]any{
			"listener": listener,
			"target":   target,
			"base":     util.Value(traffic.Base),
		})
	}

	registry := make(map[string]any)
	if microserviceInformation.Docker.Registry.Ecr != nil {
		registry["ecr"] = map[string]any{
			"privacy": microserviceInformation.Docker.Registry.Ecr.Privacy,
		}
		registry["ecr"] = util.Nil(microserviceInformation.Docker.Registry.Ecr.AccountId, registry["ecr"].(map[string]any), "account_id")
		registry["ecr"] = util.Nil(microserviceInformation.Docker.Registry.Ecr.RegionName, registry["ecr"].(map[string]any), "region_name")
		registry["ecr"] = util.Nil(microserviceInformation.Docker.Registry.Ecr.PublicAlias, registry["ecr"].(map[string]any), "public_alias")
	}
	image := make(map[string]any)
	if microserviceInformation.Docker.Image != nil {
		image = map[string]any{
			"tag": microserviceInformation.Docker.Image.Tag,
		}
	}
	docker = map[string]any{
		"registry": registry,
		"repository": map[string]any{
			"name": microserviceInformation.Docker.Repository.Name,
		},
		"image": image,
	}

	bucketEnv = map[string]any{
		"force_destroy": true,
		"versioning":    false,
		"file_key":      fmt.Sprintf("%s.env", microserviceInformation.Branch),
		"file_path":     "override.env",
	}

	return namePrefix, nameSuffix, tags, trafficsMap, docker, bucketEnv
}

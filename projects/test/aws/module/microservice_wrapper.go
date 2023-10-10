package module

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/vistimi/infrastructure-modules/test/util"

	testAwsModule "github.com/vistimi/infrastructure-modules/test/aws/module"
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
		target = util.ObjNil(traffic.Target.Port, target, "port")
		target = util.ObjNil(traffic.Target.ProtocolVersion, target, "protocol_version")
		target = util.ObjNil(traffic.Target.StatusCode, target, "status_code")

		listener := map[string]any{
			"protocol": traffic.Listener.Protocol,
		}
		listener = util.ObjNil(traffic.Listener.Port, listener, "port")
		listener = util.ObjNil(traffic.Listener.ProtocolVersion, listener, "protocol_version")

		trafficsMap = append(trafficsMap, map[string]any{
			"listener": listener,
			"target":   target,
			"base":     util.Value(traffic.Base),
		})
	}

	registry := make(map[string]any)
	registry = util.ObjNil(microserviceInformation.Docker.Registry.Name, registry, "name")
	if microserviceInformation.Docker.Registry.Ecr != nil {
		registry["ecr"] = map[string]any{
			"privacy": microserviceInformation.Docker.Registry.Ecr.Privacy,
		}
		registry["ecr"] = util.ObjNil(microserviceInformation.Docker.Registry.Ecr.AccountId, registry["ecr"].(map[string]any), "account_id")
		registry["ecr"] = util.ObjNil(microserviceInformation.Docker.Registry.Ecr.RegionName, registry["ecr"].(map[string]any), "region_name")
		registry["ecr"] = util.ObjNil(microserviceInformation.Docker.Registry.Ecr.PublicAlias, registry["ecr"].(map[string]any), "public_alias")
	}

	docker = map[string]any{
		"registry": registry,
		"repository": map[string]any{
			"name": microserviceInformation.Docker.Repository.Name,
		},
	}
	if microserviceInformation.Docker.Image != nil {
		docker["image"] = map[string]any{
			"tag": microserviceInformation.Docker.Image.Tag,
		}
	}

	bucketEnv = map[string]any{
		"force_destroy": true,
		"versioning":    false,
		"file_key":      fmt.Sprintf("%s.env", microserviceInformation.Branch),
		"file_path":     "override.env",
	}

	return namePrefix, nameSuffix, tags, trafficsMap, docker, bucketEnv
}

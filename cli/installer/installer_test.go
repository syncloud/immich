package installer

import (
	"encoding/json"
	"os"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/syncloud/golib/config"
)

func TestInstalled(t *testing.T) {
	tempDir := t.TempDir()

	installer := &Installer{
		installFile: path.Join(tempDir, "installed"),
	}
	assert.False(t, installer.IsInstalled())
	err := installer.MarkInstalled()
	assert.NoError(t, err)
	assert.True(t, installer.IsInstalled())
}

func TestMediaDir(t *testing.T) {
	assert.Equal(t, "/data/immich/media", MediaDir("/data/immich"))
}

func TestSocket(t *testing.T) {
	assert.Equal(t, "/var/snap/immich/current/immich.sock", Socket())
}

func TestModelCacheDir(t *testing.T) {
	assert.Equal(t, "/data/immich/model-cache", ModelCacheDir("/data/immich"))
}

func TestMlSocket(t *testing.T) {
	assert.Equal(t, "/var/snap/immich/current/machine-learning.sock", MlSocket())
}

func TestGenerateImmichConfigIsValidJson(t *testing.T) {
	tempDir := t.TempDir()

	err := config.Generate("../../config", tempDir, Variables{
		App:           App,
		AppDir:        AppDir,
		DataDir:       DataDir,
		CommonDir:     CommonDir,
		DatabaseDir:   path.Join(DataDir, "database"),
		MediaDir:      "/data/immich/media",
		StorageDir:    "/data/immich",
		AppUrl:        "https://immich.example.com",
		AuthUrl:       "https://auth.example.com",
		Domain:        "immich.example.com",
		OIDCSecret:    "secret",
		Socket:        Socket(),
		MobileUrl:     "https://immich.example.com" + MobileRedirectPath,
		AdminGroup:    AdminGroup,
		MlSocket:      MlSocket(),
		ModelCacheDir: ModelCacheDir("/data/immich"),
	})
	assert.NoError(t, err)

	content, err := os.ReadFile(path.Join(tempDir, "immich.json"))
	assert.NoError(t, err)

	var generated map[string]interface{}
	err = json.Unmarshal(content, &generated)
	assert.NoError(t, err)

	oauth := generated["oauth"].(map[string]interface{})
	assert.Equal(t, true, oauth["enabled"])
	assert.Equal(t, "immich", oauth["clientId"])
	assert.Equal(t, "secret", oauth["clientSecret"])
	assert.Equal(
		t,
		"https://auth.example.com/.well-known/openid-configuration",
		oauth["issuerUrl"],
	)
	assert.Equal(t, AuthMethod, oauth["tokenEndpointAuthMethod"])
	assert.Equal(t, "groups", oauth["roleClaim"])
	assert.Equal(t, "openid email profile groups", oauth["scope"])

	ml := generated["machineLearning"].(map[string]interface{})
	assert.Equal(t, true, ml["enabled"])
	assert.Equal(t, []interface{}{"http://machine-learning"}, ml["urls"])
	assert.Equal(t, true, oauth["mobileOverrideEnabled"])
	assert.Equal(
		t,
		"https://immich.example.com/api/oauth/mobile-redirect",
		oauth["mobileRedirectUri"],
	)
}

func TestGenerateEnvPointsAtBundledPaths(t *testing.T) {
	tempDir := t.TempDir()

	err := config.Generate("../../config", tempDir, Variables{
		App:           App,
		AppDir:        AppDir,
		DataDir:       DataDir,
		CommonDir:     CommonDir,
		DatabaseDir:   path.Join(DataDir, "database"),
		MediaDir:      "/data/immich/media",
		Socket:        Socket(),
		AdminGroup:    AdminGroup,
		MlSocket:      MlSocket(),
		ModelCacheDir: ModelCacheDir("/data/immich"),
	})
	assert.NoError(t, err)

	env, err := os.ReadFile(path.Join(tempDir, "env"))
	assert.NoError(t, err)
	assert.Contains(t, string(env), "export DB_HOSTNAME=/var/snap/immich/current/database")
	assert.Contains(t, string(env), "export REDIS_SOCKET=/var/snap/immich/current/redis.sock")
	assert.Contains(t, string(env), "export IMMICH_MEDIA_LOCATION=/data/immich/media")
	assert.Contains(t, string(env), "export IMMICH_SOCKET=/var/snap/immich/current/immich.sock")
	assert.NotContains(t, string(env), "IMMICH_PORT")
	assert.Contains(t, string(env), "export IMMICH_ADMIN_ROLE=syncloud")
	assert.Contains(t, string(env), "export IMMICH_ALLOW_SETUP=false")
	assert.Contains(t, string(env), "export MACHINE_LEARNING_CACHE_FOLDER=/data/immich/model-cache")
	assert.Contains(t, string(env), "export IMMICH_ML_SOCKET=/var/snap/immich/current/machine-learning.sock")

	nginx, err := os.ReadFile(path.Join(tempDir, "nginx.conf"))
	assert.NoError(t, err)
	assert.Contains(t, string(nginx), "server unix:/var/snap/immich/current/immich.sock;")
	assert.Contains(t, string(nginx), "listen unix:/var/snap/immich/common/web.socket;")
}

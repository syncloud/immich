package installer

import (
	"os"
	"path"

	cp "github.com/otiai10/copy"
	"github.com/syncloud/golib/config"
	"github.com/syncloud/golib/linux"
	"github.com/syncloud/golib/platform"
	"go.uber.org/zap"
)

const (
	App                = "immich"
	AppDir             = "/snap/immich/current"
	DataDir            = "/var/snap/immich/current"
	CommonDir          = "/var/snap/immich/common"
	OIDCPath           = "/auth/login"
	MobileRedirectPath = "/api/oauth/mobile-redirect"
	AuthMethod         = "client_secret_basic"
	AdminGroup         = "syncloud"
)

type Variables struct {
	App           string
	AppDir        string
	DataDir       string
	CommonDir     string
	DatabaseDir   string
	MediaDir      string
	StorageDir    string
	AppUrl        string
	AuthUrl       string
	Domain        string
	OIDCSecret    string
	Socket        string
	MobileUrl     string
	AdminGroup    string
	MlSocket      string
	ModelCacheDir string
}

type Installer struct {
	newVersionFile     string
	currentVersionFile string
	configDir          string
	platformClient     *platform.Client
	database           *Database
	installFile        string
	logger             *zap.Logger
}

func New(logger *zap.Logger) *Installer {
	configDir := path.Join(DataDir, "config")
	executor := NewExecutor(logger)
	return &Installer{
		newVersionFile:     path.Join(AppDir, "version"),
		currentVersionFile: path.Join(DataDir, "version"),
		configDir:          configDir,
		platformClient:     platform.New(),
		database:           NewDatabase(AppDir, DataDir, configDir, App, executor, logger),
		installFile:        path.Join(CommonDir, "installed"),
		logger:             logger,
	}
}

func (i *Installer) Install() error {
	err := i.UpdateConfigs()
	if err != nil {
		return err
	}
	err = i.database.Init()
	if err != nil {
		return err
	}
	return i.database.InitConfig()
}

func (i *Installer) Configure() error {
	if i.IsInstalled() {
		err := i.Upgrade()
		if err != nil {
			return err
		}
	} else {
		err := i.Initialize()
		if err != nil {
			return err
		}
	}

	err := i.FixPermissions()
	if err != nil {
		return err
	}

	return i.UpdateVersion()
}

func (i *Installer) IsInstalled() bool {
	_, err := os.Stat(i.installFile)
	return err == nil
}

func (i *Installer) Initialize() error {
	err := i.StorageChange()
	if err != nil {
		return err
	}
	err = i.database.CreateDatabaseIfMissing(App)
	if err != nil {
		return err
	}
	return i.MarkInstalled()
}

func (i *Installer) MarkInstalled() error {
	return os.WriteFile(i.installFile, []byte("installed"), 0644)
}

func (i *Installer) Upgrade() error {
	err := i.database.Restore()
	if err != nil {
		return err
	}
	err = i.StorageChange()
	if err != nil {
		return err
	}
	return i.database.CreateDatabaseIfMissing(App)
}

func (i *Installer) PreRefresh() error {
	return i.database.Backup()
}

func (i *Installer) PostRefresh() error {
	err := i.UpdateConfigs()
	if err != nil {
		return err
	}
	err = i.database.Remove()
	if err != nil {
		return err
	}
	err = i.database.Init()
	if err != nil {
		return err
	}
	err = i.database.InitConfig()
	if err != nil {
		return err
	}
	err = i.ClearVersion()
	if err != nil {
		return err
	}
	return i.FixPermissions()
}

func (i *Installer) AccessChange() error {
	return i.UpdateConfigs()
}

func (i *Installer) StorageChange() error {
	storageDir, err := i.platformClient.InitStorage(App, App)
	if err != nil {
		return err
	}
	err = linux.CreateMissingDirs(MediaDir(storageDir), ModelCacheDir(storageDir))
	if err != nil {
		return err
	}
	return linux.Chown(storageDir, App)
}

func (i *Installer) ClearVersion() error {
	return os.RemoveAll(i.currentVersionFile)
}

func (i *Installer) UpdateVersion() error {
	return cp.Copy(i.newVersionFile, i.currentVersionFile)
}

func (i *Installer) UpdateConfigs() error {
	err := linux.CreateUser(App)
	if err != nil {
		return err
	}

	err = i.StorageChange()
	if err != nil {
		return err
	}

	err = linux.CreateMissingDirs(
		path.Join(DataDir, "nginx"),
		path.Join(DataDir, "tmp"),
	)
	if err != nil {
		return err
	}

	storageDir, err := i.platformClient.InitStorage(App, App)
	if err != nil {
		return err
	}

	domain, err := i.platformClient.GetAppDomainName(App)
	if err != nil {
		return err
	}

	appUrl, err := i.platformClient.GetAppUrl(App)
	if err != nil {
		return err
	}

	authUrl, err := i.platformClient.GetAppUrl("auth")
	if err != nil {
		return err
	}

	secret, err := i.platformClient.RegisterOIDCClient(
		App,
		[]string{OIDCPath, MobileRedirectPath},
		false,
		AuthMethod,
	)
	if err != nil {
		return err
	}

	variables := Variables{
		App:           App,
		AppDir:        AppDir,
		DataDir:       DataDir,
		CommonDir:     CommonDir,
		DatabaseDir:   i.database.DatabaseDir(),
		MediaDir:      MediaDir(storageDir),
		StorageDir:    storageDir,
		AppUrl:        appUrl,
		AuthUrl:       authUrl,
		Domain:        domain,
		OIDCSecret:    secret,
		Socket:        Socket(),
		MobileUrl:     appUrl + MobileRedirectPath,
		AdminGroup:    AdminGroup,
		MlSocket:      MlSocket(),
		ModelCacheDir: ModelCacheDir(storageDir),
	}

	err = config.Generate(path.Join(AppDir, "config"), i.configDir, variables)
	if err != nil {
		return err
	}

	return i.FixPermissions()
}

func (i *Installer) FixPermissions() error {
	storageDir, err := i.platformClient.InitStorage(App, App)
	if err != nil {
		return err
	}
	err = linux.Chown(DataDir, App)
	if err != nil {
		return err
	}
	err = linux.Chown(CommonDir, App)
	if err != nil {
		return err
	}
	return linux.Chown(storageDir, App)
}

func (i *Installer) BackupPreStop() error {
	return i.PreRefresh()
}

func (i *Installer) RestorePreStart() error {
	return i.PostRefresh()
}

func (i *Installer) RestorePostStart() error {
	return i.Configure()
}

func MediaDir(storageDir string) string {
	return path.Join(storageDir, "media")
}

func ModelCacheDir(storageDir string) string {
	return path.Join(storageDir, "model-cache")
}

func MlSocket() string {
	return path.Join(DataDir, "machine-learning.sock")
}

func Socket() string {
	return path.Join(DataDir, "immich.sock")
}

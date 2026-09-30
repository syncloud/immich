local name = 'immich';
local version = 'v3.2.2';
local postgresql = '14-vectorchord0.4.3-pgvectors0.2.0';
local valkey = '9.1.2';

local go = '1.25';
local nginx = '1.30.4';
local debian = 'bookworm-slim';
local python = '3.12-slim-bookworm';
local platform = '26.09.02';
local playwright = 'mcr.microsoft.com/playwright:v1.59.1-jammy';
local store_publisher = 'stable-346';
local distro_default = 'bookworm';
local distros = ['bookworm', 'buster'];

local platform_image(distro) = 'syncloud/platform-' + distro + ':' + platform;

local full_domain = distro_default + '.com';
local app_domain = name + '.' + full_domain;

local e2e(step, artifact, spec) = {
  name: step,
  image: playwright,
  environment: {
    PLAYWRIGHT_FULL_DOMAIN: full_domain,
    PLAYWRIGHT_APP_DOMAIN: app_domain,
    PLAYWRIGHT_DEVICE_HOST: app_domain,
    PLAYWRIGHT_DEVICE_USER: 'user',
    PLAYWRIGHT_DEVICE_PASSWORD: 'Password1',
    PLAYWRIGHT_SSH_USER: 'root',
    PLAYWRIGHT_SSH_PASSWORD: 'Password1',
    PLAYWRIGHT_SAMPLES: '/drone/src/test/samples',
  },
  commands: ['./test/e2e/run.sh ' + artifact + ' specs/' + spec + '.spec.ts desktop'],
};

local snapd_hold = "mkdir -p /etc/systemd/system/snapd.service.d && printf '[Service]\\nExecStartPost=/bin/sh -c \"/usr/bin/snap set system refresh.hold=2099-01-01T00:00:00Z\"\\n' > /etc/systemd/system/snapd.service.d/disable-refresh.conf && exec /sbin/init";

local build(arch, test_ui) = [{
  kind: 'pipeline',
  type: 'docker',
  name: arch,
  platform: {
    os: 'linux',
    arch: arch,
  },
  steps: [
    {
      name: 'nginx',
      image: 'nginx:' + nginx,
      commands: ['./nginx/build.sh'],
    },
  ] + [
    {
      name: 'nginx test ' + distro,
      image: platform_image(distro),
      commands: ['./nginx/test.sh'],
    }
    for distro in distros
  ] + [
    {
      name: 'redis',
      image: 'valkey/valkey:' + valkey,
      commands: ['./redis/build.sh'],
    },
  ] + [
    {
      name: 'redis test ' + distro,
      image: platform_image(distro),
      commands: ['./redis/test.sh'],
    }
    for distro in distros
  ] + [
    {
      name: 'postgresql',
      image: 'ghcr.io/immich-app/postgres:' + postgresql,
      commands: ['./postgresql/build.sh'],
    },
  ] + [
    {
      name: 'postgresql test ' + distro,
      image: platform_image(distro),
      commands: ['./postgresql/test.sh'],
    }
    for distro in distros
  ] + [
    {
      name: 'immich',
      image: 'ghcr.io/immich-app/immich-server:' + version,
      commands: ['./immich/build.sh'],
    },
  ] + [
    {
      name: 'immich test ' + distro,
      image: platform_image(distro),
      commands: ['./immich/test.sh'],
    }
    for distro in distros
  ] + [
    {
      name: 'ml',
      image: 'ghcr.io/immich-app/immich-machine-learning:' + version,
      commands: ['./ml/build.sh'],
    },
  ] + [
    {
      name: 'ml test ' + distro,
      image: platform_image(distro),
      commands: ['./ml/test.sh'],
    }
    for distro in distros
  ] + [
    {
      name: 'cli',
      image: 'golang:' + go,
      commands: ['./cli/build.sh'],
    },
  ] + [
    {
      name: 'cli test ' + distro,
      image: platform_image(distro),
      commands: ['./cli/test.sh'],
    }
    for distro in distros
  ] + [
    {
      name: 'package',
      image: 'debian:' + debian,
      commands: ['./package.sh ' + name + ' $DRONE_BUILD_NUMBER'],
    },
  ] + [
    {
      name: 'test ' + distro,
      image: 'python:' + python,
      commands: ['./ci/test.sh test.py ' + distro + ' ' + name],
    }
    for distro in distros
  ] + (if test_ui then [
         e2e('e2e', 'e2e', '01-smoke'),
         e2e('e2e admin group', 'e2e-admin-group', '04-admin-group'),
         e2e('e2e ui', 'e2e-ui', '05-ui'),
         {
           name: 'test-upgrade-prev',
           image: 'python:' + python,
           commands: ['./ci/test.sh upgrade_prev.py ' + distro_default + ' ' + name],
         },
         e2e('e2e-before-upgrade', 'e2e-before-upgrade', '02-pre-upgrade'),
         {
           name: 'test-upgrade',
           image: 'python:' + python,
           commands: ['./ci/test.sh upgrade.py ' + distro_default + ' ' + name],
         },
         e2e('e2e-after-upgrade', 'e2e-after-upgrade', '03-post-upgrade'),
       ] else []) + [
    {
      name: 'publish',
      image: 'syncloud/store-publisher:' + store_publisher,
      environment: {
        SYNCLOUD_TOKEN: { from_secret: 'SYNCLOUD_TOKEN' },
      },
      command: ['snap', '-c', '${DRONE_BRANCH}'],
      when: {
        branch: ['stable'],
        event: ['push'],
      },
    },
    {
      name: 'artifact',
      image: 'appleboy/drone-scp:1.6.4',
      settings: {
        host: { from_secret: 'artifact_host' },
        username: 'artifact',
        key: { from_secret: 'artifact_key' },
        timeout: '2m',
        command_timeout: '5m',
        target: '/home/artifact/repo/' + name + '/${DRONE_BUILD_NUMBER}-' + arch,
        source: 'artifact/*',
        strip_components: 1,
      },
      when: {
        status: ['failure', 'success'],
      },
    },
  ],
  trigger: {
    event: ['push'],
  },
  services: [
    {
      name: name + '.' + distro + '.com',
      image: platform_image(distro),
      privileged: true,
      entrypoint: ['/bin/sh', '-c', snapd_hold],
      volumes: [
        { name: 'dbus', path: '/var/run/dbus' },
        { name: 'dev', path: '/dev' },
      ],
    }
    for distro in distros
  ],
  volumes: [
    { name: 'dbus', host: { path: '/var/run/dbus' } },
    { name: 'dev', host: { path: '/dev' } },
  ],
}];

build('amd64', true) +
build('arm64', false)

import pytest
import requests
from subprocess import check_output
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.installer import local_install
from syncloudlib.http import wait_for_rest

TMP_DIR = '/tmp/syncloud'
BEFORE = {}


@pytest.fixture(scope="session")
def module_setup(request, device, artifact_dir):
    def module_teardown():
        device.run_ssh('mkdir -p {0}'.format(TMP_DIR), throw=False)
        device.run_ssh('journalctl > {0}/upgrade.journalctl.log'.format(TMP_DIR), throw=False)
        device.scp_from_device('{0}/*'.format(TMP_DIR), artifact_dir, throw=False)
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


def psql(device, sql):
    return device.run_ssh("snap run immich.psql -U immich -d immich -t -A -c '{0}'".format(sql))


def count(device, table):
    out = psql(device, 'select count(*) from {0}'.format(table))
    for line in reversed(out.strip().split('\n')):
        line = line.strip()
        if line.isdigit():
            return int(line)
    raise AssertionError('no row count in psql output: {0}'.format(out))


def test_start(module_setup, app, device_host, domain, device):
    add_host_alias(app, device_host, domain)
    device.activated()
    device.run_ssh('mkdir -p {0}'.format(TMP_DIR), throw=False)


def test_record_state_before_upgrade(device):
    BEFORE['assets'] = count(device, 'asset')
    assert BEFORE['assets'] > 0, 'e2e-before-upgrade should have seeded an asset'


def test_upgrade(device_host, device_password, app_archive_path, app_domain):
    local_install(device_host, device_password, app_archive_path)
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_assets_survived(device):
    assert count(device, 'asset') == BEFORE['assets']


def test_vectorchord_still_installed(device):
    out = psql(device, 'select extname from pg_extension')
    assert 'vchord' in out, out


def test_services_running_after_upgrade(device):
    out = device.run_ssh('snap services immich')
    rows = [line.split() for line in out.strip().split('\n')[1:] if line.strip()]
    not_active = [row[0] for row in rows if len(row) >= 3 and row[2] != 'active']
    assert not not_active, (not_active, out)

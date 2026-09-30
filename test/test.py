import json
import time
from os.path import dirname
from subprocess import check_output
from urllib.parse import quote_plus

import pytest
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from syncloudlib.http import wait_for_rest
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.installer import local_install

DIR = dirname(__file__)
TMP_DIR = '/tmp/syncloud'

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


@pytest.fixture(scope="session")
def module_setup(request, device, artifact_dir):
    def module_teardown():
        device.run_ssh('mkdir -p {0}'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/immich/current > {0}/data.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/immich/current/config > {0}/config.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/immich/current/config/env > {0}/env.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/immich/current/config/immich.json > {0}/immich.json.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/immich/current/config/nginx.conf > {0}/nginx.conf.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/immich/current/database/postgresql.conf > {0}/postgresql.conf.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /data/immich /data/immich/media > {0}/storage.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('snap services immich > {0}/services.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ps auxfw > {0}/ps.log'.format(TMP_DIR), throw=False)
        device.run_ssh('netstat -nlp > {0}/netstat.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/immich/current/*.sock* > {0}/sockets.log'.format(TMP_DIR), throw=False)
        device.run_ssh('free -m > {0}/free.log'.format(TMP_DIR), throw=False)
        device.run_ssh('df -h > {0}/df.log'.format(TMP_DIR), throw=False)
        device.run_ssh('journalctl > {0}/journalctl.log'.format(TMP_DIR), throw=False)
        device.scp_from_device('{0}/*'.format(TMP_DIR), artifact_dir, throw=False)
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


def settle(device):
    device.run_ssh('snap wait system seed.loaded', retries=100, throw=False)
    device.run_ssh('snap set system refresh.hold=2099-01-01T00:00:00Z', retries=20, throw=False)
    device.run_ssh('snap abort --last=auto-refresh', throw=False)
    device.run_ssh('snap watch --last=auto-refresh', throw=False)


def test_start(module_setup, device, device_host, app, domain):
    add_host_alias(app, device_host, domain)
    device.run_ssh('date', retries=100)
    device.run_ssh('mkdir -p {0}'.format(TMP_DIR))


@pytest.mark.flaky(retries=50, delay=10)
def test_activate_device(device):
    settle(device)
    device.run_ssh('rm -f /var/snap/platform/current/syncloud.crt', throw=False)
    response = retry(device.activate_custom)
    assert response.status_code == 200, response.text


def test_ca_cert(device, app_domain):
    device.run_ssh(
        'CURL_CA_BUNDLE=/var/snap/platform/current/syncloud.ca.crt curl -v https://{0} > {1}/ssl.ca.log 2>&1'.format(
            app_domain, TMP_DIR))


def test_install(app_archive_path, device_host, device_password, device):
    settle(device)
    device.run_ssh('touch /var/snap/platform/current/CI_TEST')
    local_install(device_host, device_password, app_archive_path)


def test_index(app_domain):
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_services_running(device):
    assert_all_services_active(device)


def test_listens_on_unix_sockets(device):
    device.run_ssh('test -S /var/snap/immich/current/immich.sock', retries=100)
    device.run_ssh('test -S /var/snap/immich/current/immich.sock.microservices', retries=100)


def test_machine_learning_listens_on_a_socket(device):
    device.run_ssh('test -S /var/snap/immich/current/machine-learning.sock', retries=100)
    device.run_ssh(
        'curl -f -s --unix-socket /var/snap/immich/current/machine-learning.sock http://ml/ping',
        retries=100)


def test_no_tcp_listeners(device):
    out = device.run_ssh('netstat -nltp')
    ours = [line for line in out.split('\n') if 'immich' in line or ':3003' in line]
    assert not ours, out


def test_machine_learning_threads_are_capped(device):
    out = device.run_ssh('journalctl -u snap.immich.ml')
    assert 'Initialized request thread pool with 2 threads' in out, out[-2000:]


def test_model_cache_is_in_storage(device):
    device.run_ssh('test -d /data/immich/model-cache')


def test_database_uses_vectorchord(device):
    out = device.run_ssh(
        "snap run immich.psql -U immich -d immich -t -A -c 'select extname from pg_extension'",
        retries=20)
    assert 'vchord' in out, out


def test_setup_is_disabled(app_domain):
    response = requests.post(
        'https://{0}/api/auth/admin-sign-up'.format(app_domain),
        json={'email': 'nobody@example.com', 'password': 'Password1', 'name': 'Nobody'},
        verify=False)
    assert response.status_code == 400, response.text


def test_oauth_is_configured(app_domain):
    response = requests.get('https://{0}/api/public/config'.format(app_domain), verify=False)
    assert response.status_code == 200, response.text
    config = response.json()
    assert config['oauth']['enabled'], response.text
    assert config['oauth']['buttonText'] == 'Login with Syncloud', response.text


def test_oauth_authorize_redirects_to_authelia(app_domain):
    response = requests.post(
        'https://{0}/api/oauth/authorize'.format(app_domain),
        json={'redirectUri': 'https://{0}/auth/login'.format(app_domain)},
        verify=False)
    assert response.status_code == 201, response.text
    url = response.json()['url']
    assert 'auth.' in url, url


def test_oauth_mobile_redirect_is_registered(app_domain):
    response = requests.post(
        'https://{0}/api/oauth/authorize'.format(app_domain),
        json={'redirectUri': 'app.immich:///oauth-callback'},
        verify=False)
    assert response.status_code == 201, response.text
    url = response.json()['url']
    expected = quote_plus('https://{0}/api/oauth/mobile-redirect'.format(app_domain))
    assert expected in url, url


def test_oauth_mobile_redirect_forwards_to_the_app(app_domain):
    response = requests.get(
        'https://{0}/api/oauth/mobile-redirect?code=abc&state=xyz'.format(app_domain),
        verify=False, allow_redirects=False)
    assert 300 <= response.status_code < 400, response.text
    location = response.headers.get('Location', '')
    assert location.startswith('app.immich:///oauth-callback?'), location
    assert 'code=abc' in location, location


def test_storage_change_event(device):
    device.run_ssh('snap run immich.storage-change > {0}/storage-change.log'.format(TMP_DIR))


def test_access_change_event(device):
    device.run_ssh('snap run immich.access-change > {0}/access-change.log'.format(TMP_DIR))


def test_index_after_events(app_domain):
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_remove(device, app):
    response = device.app_remove(app)
    assert response.status_code == 200, response.text


def test_reinstall(app_archive_path, device_host, device_password, app_domain):
    local_install(device_host, device_password, app_archive_path)
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def test_upgrade(app_archive_path, device_host, device_password, app_domain, device):
    local_install(device_host, device_password, app_archive_path)
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)
    assert_all_services_active(device)


def test_backup(device, artifact_dir, app_domain):
    wait_for_snap_changes(device)
    out = device.run_ssh('snap run platform.cli backup create immich', retries=10, throw=False)
    response = device.run_ssh('snap run platform.cli backup list')
    open('{0}/cli.backup.list.json'.format(artifact_dir), 'w').write(response)
    backups = json.loads(response)
    assert backups, 'backup create failed:\n{0}'.format(out)
    backup = backups[0]
    device.run_ssh('tar tvf {0}/{1}'.format(backup['path'], backup['file']))
    device.run_ssh('snap run platform.cli backup restore {0}'.format(backup['file']))
    wait_for_rest(requests.session(), 'https://{0}'.format(app_domain), 200, 100)


def wait_for_snap_changes(device):
    for _ in range(12):
        if 'Doing' not in device.run_ssh('snap changes', throw=False):
            return
        time.sleep(10)


def assert_all_services_active(device):
    out = device.run_ssh('snap services immich')
    rows = [line.split() for line in out.strip().split('\n')[1:] if line.strip()]
    daemons = [row for row in rows if len(row) >= 3 and row[2] != '-']
    not_active = [row[0] for row in daemons if row[2] != 'active']
    assert not not_active, (not_active, out)


def retry(method, retries=10, delay=5):
    attempt = 0
    exception = None
    while attempt < retries:
        try:
            return method()
        except Exception as e:
            exception = e
            print('error (attempt {0}/{1}): {2}'.format(attempt + 1, retries, str(e)))
            time.sleep(delay)
        attempt += 1
    raise exception

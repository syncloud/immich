DAEMONS = ['postgresql', 'redis', 'immich', 'ml', 'nginx']


def restarts(device):
    counts = {}
    for daemon in DAEMONS:
        out = device.run_ssh('systemctl show -p NRestarts --value snap.immich.{0}.service'.format(daemon))
        counts[daemon] = out.strip()
    return counts


def assert_no_restarts(device):
    counts = restarts(device)
    restarted = {daemon: count for daemon, count in counts.items() if count != '0'}
    assert not restarted, counts

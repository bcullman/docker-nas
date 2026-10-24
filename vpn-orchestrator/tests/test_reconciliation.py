"""Exercise the deployed shell functions with fake Docker and Portainer calls."""
import pathlib
import subprocess
import tempfile
import unittest

COMPOSE = pathlib.Path(__file__).resolve().parents[1] / 'docker-compose.yml'


class ReconciliationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        text = COMPOSE.read_text()
        block = text.split('      - |\n', 1)[1].split('        mkdir -p /state', 1)[0]
        self.functions = '\n'.join(line[8:] for line in block.splitlines()).replace('$$', '$')
        self.functions = self.functions.replace('/state/', str(self.root) + '/')
        for name in ['good', 'bad']:
            (self.root / name).write_text('running')
        self.write('generation', 'generation-1')

    def write(self, name, value):
        (self.root / name).write_text(value)

    def run_shell(self, command):
        mocks = r'''
PORTAINER_ENDPOINT_ID=3
DEPENDENTS="1:good 2:bad"
vpn_generation() { cat "$TEST_ROOT/generation"; }
vpn_is_healthy() { return 0; }
container_is_healthy() { [ "$(cat "$TEST_ROOT/$1")" = running ]; }
docker() { eval 'name=${'$#'}'; cat "$TEST_ROOT/$name"; }
post() {
  echo "$1" >> "$TEST_ROOT/calls"
  case "$1" in */1/*) name=good ;; *) name=bad ;; esac
  case "$1" in
    */stop\?*)
      [ ! -f "$TEST_ROOT/fail-stop-$name" ] || return 1
      echo exited > "$TEST_ROOT/$name"
      if [ -f "$TEST_ROOT/change-generation" ]; then
        echo generation-2 > "$TEST_ROOT/generation"
      fi
      ;;
    */start\?*)
      [ ! -f "$TEST_ROOT/fail-start-$name" ] || return 1
      echo running > "$TEST_ROOT/$name"
      ;;
  esac
}
wait_for_dependents() {
  [ "$(vpn_generation)" = "$1" ] && dependents_are_healthy
}
'''
        result = subprocess.run(['sh', '-c', self.functions + mocks + '\n' + command],
                                env={'PATH': '/usr/bin:/bin', 'TEST_ROOT': str(self.root)},
                                capture_output=True, text=True)
        return result.returncode

    def calls(self):
        return (self.root / 'calls').read_text().splitlines()

    def reconcile(self):
        return self.run_shell('reconcile_dependents "$(vpn_generation)" "$DEPENDENTS" test')

    def test_failed_start_retries_only_failed_service_across_processes(self):
        self.write('fail-start-bad', '')
        self.assertNotEqual(self.reconcile(), 0)
        self.assertFalse((self.root / 'vpn-container-id').exists())
        self.assertTrue((self.root / 'reconciled-1').exists())
        (self.root / 'fail-start-bad').unlink()
        self.assertEqual(self.reconcile(), 0)
        self.assertEqual(self.calls().count('/api/stacks/1/stop?endpointId=3'), 1)
        self.assertEqual(self.calls().count('/api/stacks/1/start?endpointId=3'), 1)
        self.assertEqual(self.calls().count('/api/stacks/2/stop?endpointId=3'), 1)
        self.assertEqual(self.calls().count('/api/stacks/2/start?endpointId=3'), 2)
        self.assertEqual((self.root / 'vpn-container-id').read_text().strip(), 'generation-1')

    def test_new_generation_reconciles_every_service(self):
        self.assertEqual(self.reconcile(), 0)
        self.write('generation', 'generation-2')
        self.assertEqual(self.reconcile(), 0)
        self.assertEqual(len(self.calls()), 8)

    def test_unhealthy_completed_service_is_retried(self):
        self.assertEqual(self.reconcile(), 0)
        self.write('bad', 'unhealthy')
        self.assertEqual(self.reconcile(), 0)
        self.assertEqual(self.calls().count('/api/stacks/1/start?endpointId=3'), 1)
        self.assertEqual(self.calls().count('/api/stacks/2/start?endpointId=3'), 2)

    def test_failed_stop_does_not_start_or_complete_service(self):
        self.write('fail-stop-bad', '')
        self.assertNotEqual(self.reconcile(), 0)
        self.assertNotIn('/api/stacks/2/start?endpointId=3', self.calls())
        self.assertFalse((self.root / 'reconciled-2').exists())
        self.assertFalse((self.root / 'vpn-container-id').exists())

    def test_vpn_change_during_stop_prevents_start(self):
        self.write('change-generation', '')
        self.assertNotEqual(self.run_shell('reconcile_dependency generation-1 1:good'), 0)
        self.assertEqual(self.calls(), ['/api/stacks/1/stop?endpointId=3'])
        self.assertFalse((self.root / 'reconciled-1').exists())


if __name__ == '__main__':
    unittest.main()

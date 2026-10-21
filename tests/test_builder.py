import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class BuilderTests(unittest.TestCase):
    def test_workflow_manual(self):
        data = (ROOT / '.github/workflows/build-sharex-portable.yml').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:', data)
        self.assertIn('windows-latest', data)
        self.assertIn('upload-artifact@v4', data)
        self.assertIn('retention-days: 1', data)

    def test_official_stable_release(self):
        script = (ROOT / 'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertIn('ShareX-', script)
        self.assertIn('portable-x64.zip', script)
        self.assertIn('Get-FileHash', script)
        self.assertIn('Expected exact official asset', script)
        self.assertIn('No official SHA-256', script)

    def test_launcher_uses_data_path(self):
        cs = (ROOT / 'launcher/ShareXPortable.cs').read_text(encoding='utf-8')
        self.assertIn('"Data", "ShareX"', cs)
        self.assertIn('PersonalPath.cfg', cs)
        self.assertIn('UTF8Encoding(false)', cs)
        self.assertIn('ExistingPersonalPathOverride', cs)
        self.assertIn('RunFallback', cs)

    def test_no_aggressive_remnants_cleanup(self):
        cs = (ROOT / 'launcher/ShareXPortable.cs').read_text(encoding='utf-8')
        self.assertNotIn('RegistryKey.DeleteSubKey', cs)
        self.assertNotIn('Environment.SetEnvironmentVariable', cs)
        self.assertNotIn('HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run', cs)

    def test_original_icon(self):
        script = (ROOT / 'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertIn('getsharex.com/img/ShareX_Icon_Full.ico', script)
        self.assertIn('appicon.ico', script)
        self.assertIn('appicon_256.png', (script + 'appicon_256.png'))

    def test_package_has_single_outer_directory(self):
        script = (ROOT / 'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertIn('Compress-Archive -LiteralPath $stage', script)
        self.assertIn('Type=PortableApps.comFormat', script)
        self.assertIn('AppInfo', script)

    def test_builder_docs_exist(self):
        self.assertTrue((ROOT / 'docs/TESTING.md').exists())
        self.assertTrue((ROOT / 'README.md').exists())
        self.assertTrue((ROOT / '.gitignore').exists())

    def test_no_user_data_in_repo(self):
        self.assertFalse((ROOT / 'Data').exists())
        self.assertIn('Data/', (ROOT / '.gitignore').read_text(encoding='utf-8'))

if __name__ == '__main__':
    unittest.main()

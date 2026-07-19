import subprocess
import os
import unittest

class TestMakoCLI(unittest.TestCase):
    def setUp(self):
        self.mako_path = os.path.join(os.path.dirname(__file__), "..", "BAS", "mako")
        self.test_lua_path = os.path.join(os.path.dirname(__file__), "test.lua")
        
        # Ensure test.lua exists
        if not os.path.exists(self.test_lua_path):
            with open(self.test_lua_path, "w") as f:
                f.write('print("HEllo from test.lua")\n')

    def test_e_flag(self):
        # Mako should act as a Lua interpreter and exit after running -e
        cmd = [self.mako_path, "-e", "print('hello from cli')"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("hello from cli", result.stderr)

    def test_script_execution(self):
        # Mako should act as a Lua interpreter and exit after running the script
        cmd = [self.mako_path, self.test_lua_path]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("HEllo from test.lua", result.stderr)

if __name__ == '__main__':
    unittest.main()

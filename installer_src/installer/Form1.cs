using System.Runtime.CompilerServices;

namespace installer
{
    public partial class Form1 : Form
    {
        private string selectedHLDir = string.Empty;
        private string selectedModDir = string.Empty;
        public Form1()
        {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            this.MaximizeBox = false;
            this.Text = "CS CZ Greek Mod installer";
        }

        private void button1_Click(object sender, EventArgs e)
        {
            // 1. Instantiate the FolderBrowserDialog component
            using (FolderBrowserDialog folderBrowserDialog1 = new FolderBrowserDialog())
            {
                string defaultPath = @"C:\Program Files (x86)\Steam\steamapps\common\Half-Life";

                // 2. Assign the target default directory
                if (Directory.Exists(defaultPath))
                {
                    folderBrowserDialog1.InitialDirectory = defaultPath;
                }
                else
                {
                    // Fallback if they don't have Steam on the C: drive
                    folderBrowserDialog1.InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyComputer);
                }

                // 3. Customize the dialog window interface
                folderBrowserDialog1.Description = "Select your main Half-Life installation directory";
                folderBrowserDialog1.UseDescriptionForTitle = true; // Clean window title banner
                folderBrowserDialog1.ShowNewFolderButton = false;   // Disables creating random junk folders

                // 4. Pop open the window and handle the selection outcome
                if (folderBrowserDialog1.ShowDialog() == DialogResult.OK)
                {
                    // Grab the clean directory string chosen by the user
                    string selectedFolderPath = folderBrowserDialog1.SelectedPath;

                    // Output it straight to your textbox or configuration variable
                    tb1.Text = selectedFolderPath;
                    selectedHLDir = selectedFolderPath;
                }
            }
        }

        private void button2_Click(object sender, EventArgs e)
        {
            using (FolderBrowserDialog folderBrowserDialog2 = new FolderBrowserDialog())
            {
                // Environment.SpecialFolder handles looking up the exact local user profile desktop path 
                // dynamically (e.g., C:\Users\YourUsername\Desktop) regardless of the computer username.
                string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);

                if (Directory.Exists(desktopPath))
                {
                    folderBrowserDialog2.InitialDirectory = desktopPath;
                }
                else
                {
                    folderBrowserDialog2.InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyComputer);
                }

                folderBrowserDialog2.Description = "Select your target mod working folder from the Desktop";
                folderBrowserDialog2.UseDescriptionForTitle = true;
                folderBrowserDialog2.ShowNewFolderButton = true; // Enabled here in case they need to create a folder on desktop

                if (folderBrowserDialog2.ShowDialog() == DialogResult.OK)
                {
                    // Assign the folder path to your second configuration textbox
                    tb2.Text = folderBrowserDialog2.SelectedPath;
                    selectedModDir = folderBrowserDialog2.SelectedPath;
                }
            }
        }

        private void button3_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(selectedHLDir) || string.IsNullOrEmpty(selectedModDir))
            {
                MessageBox.Show("Please select both directories first.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            try
            {
                Dictionary<string, string> deletionMap = new Dictionary<string, string>
    {
        { Path.Combine(selectedHLDir, "czero", "custom.hpk"), "Tattoo fix" } 
       
    };

                // 2. Execute Deletions BEFORE running copy operations
                foreach (KeyValuePair<string, string> target in deletionMap)
                {
                    string pathToDelete = target.Key;
                    string description = target.Value;

                    // Check if the target path points to an individual FILE
                    if (File.Exists(pathToDelete))
                    {
                        File.Delete(pathToDelete);
                        // Optional: Log it somewhere or update a status label
                        // lblStatus.Text = $"Purged: {description}";
                    }
                    // Check if the target path points to an entire DIRECTORY (Folder)
                    else if (Directory.Exists(pathToDelete))
                    {
                        // recursive: true forces it to delete all files and subfolders inside it, 
                        // otherwise Windows throws an "IO Exception: Directory not empty" crash.
                        Directory.Delete(pathToDelete, recursive: true);
                    }
                }

                // 1. Dictionary for Folders (Directories)
                Dictionary<string, string> folderMap = new Dictionary<string, string>
        {
            { Path.Combine(selectedModDir, "amx","liblist.gam"), Path.Combine(selectedHLDir, "czero","liblist.gam") },
            { Path.Combine(selectedModDir, "COPY TO ROOT","platform","servers","serverbrowser_english.txt"), Path.Combine(selectedHLDir, "platform","servers","serverbrowser_english.txt") },
            { Path.Combine(selectedModDir, "COPY TO ROOT CZERO","config.cfg"), Path.Combine(selectedHLDir, "czero","config.cfg") },
            { Path.Combine(selectedModDir, "COPY TO ROOT CZERO","custom.hpk"), Path.Combine(selectedHLDir, "czero","custom.hpk") },
            { Path.Combine(selectedModDir, "COPY TO ROOT CZERO","listenserver.cfg"), Path.Combine(selectedHLDir, "czero","listenserver.cfg") },
            { Path.Combine(selectedModDir, "COPY TO ROOT CZERO","tempdecal.wad"), Path.Combine(selectedHLDir, "czero","tempdecal.wad") },
            { Path.Combine(selectedModDir, "COPY TO ROOT CZERO","logos","remapped.bmp"), Path.Combine(selectedHLDir, "czero","logos","remapped.bmp") },
            { Path.Combine(selectedModDir, "COPY TO ROOT VALVE","resource","valve_english.txt"), Path.Combine(selectedHLDir, "valve","resource","valve_english.txt") },
            { Path.Combine(selectedModDir, "de_vegas.wad"), Path.Combine(selectedHLDir, "czero","de_vegas.wad") },
              { Path.Combine(selectedModDir, "de_vegas.wad"), Path.Combine(selectedHLDir, "de_vegas.wad") },
            
                };

                // 2. Dictionary for SINGLE FILES
                // Key = Exact source file path, Value = Exact target destination file path
                Dictionary<string, string> fileMap = new Dictionary<string, string>
        {
            { Path.Combine(selectedModDir, "amx","addons","amxmodx"), Path.Combine(selectedHLDir, "czero","addons","amxmodx")  },
              { Path.Combine(selectedModDir, "amx","addons","metamod"), Path.Combine(selectedHLDir, "czero","addons","metamod")  },
                { Path.Combine(selectedModDir, "cstrike_addon"), Path.Combine(selectedHLDir, "cstrike_addon")  },
                  { Path.Combine(selectedModDir, "czero_addon"), Path.Combine(selectedHLDir, "czero_addon")  },
                    { Path.Combine(selectedModDir, "czero_downloads"), Path.Combine(selectedHLDir,"czero_downloads")  },
        };

                // --- Process Folders ---
                foreach (KeyValuePair<string, string> entry in folderMap)
                {
                    if (Directory.Exists(entry.Key))
                    {
                        CopyDirectoryRecursive(entry.Key, entry.Value);
                    }
                }

                // --- Process Single Files ---
                foreach (KeyValuePair<string, string> entry in fileMap)
                {
                    string sourceFile = entry.Key;
                    string destFile = entry.Value;

                    // Check if the individual file exists before trying to copy it
                    if (File.Exists(sourceFile))
                    {
                        // Ensure the destination folder tree exists, otherwise File.Copy crashes
                        string destFolder = Path.GetDirectoryName(destFile);
                        if (!Directory.Exists(destFolder))
                        {
                            Directory.CreateDirectory(destFolder);
                        }

                        // Copy the single file over (overwrite: true replaces it if it's already there)
                        File.Copy(sourceFile, destFile, overwrite: true);
                    }
                }

                MessageBox.Show("Installation complete!", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}", "Failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        // 4. Add this helper method inside your Form1 class to handle subfolders recursively
        private void CopyDirectoryRecursive(string sourceDir, string targetDir)
        {
            // Create the target directory tree if missing
            Directory.CreateDirectory(targetDir);

            // Copy all individual files
            foreach (string file in Directory.GetFiles(sourceDir))
            {
                string targetFile = Path.Combine(targetDir, Path.GetFileName(file));
                File.Copy(file, targetFile, overwrite: true); // Force-overwrite files
            }

            // Recurse cleanly through all subdirectories
            foreach (string subDir in Directory.GetDirectories(sourceDir))
            {
                string targetSubDir = Path.Combine(targetDir, Path.GetFileName(subDir));
                CopyDirectoryRecursive(subDir, targetSubDir);
            }
        }
    }
}

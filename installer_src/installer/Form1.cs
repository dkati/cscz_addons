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
            if (selectedHLDir == string.Empty || selectedModDir == string.Empty)
            {
                MessageBox.Show("Please select both the Half-Life directory and the Mod directory before proceeding.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
        }
    }
}

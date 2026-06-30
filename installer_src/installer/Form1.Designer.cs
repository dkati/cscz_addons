namespace installer
{
    partial class Form1
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            button1 = new Button();
            tb1 = new TextBox();
            button2 = new Button();
            tb2 = new TextBox();
            button3 = new Button();
            folderBrowserDialog1 = new FolderBrowserDialog();
            folderBrowserDialog2 = new FolderBrowserDialog();
            pictureBox1 = new PictureBox();
            ((System.ComponentModel.ISupportInitialize)pictureBox1).BeginInit();
            SuspendLayout();
            // 
            // button1
            // 
            button1.Location = new Point(12, 12);
            button1.Name = "button1";
            button1.Size = new Size(173, 35);
            button1.TabIndex = 0;
            button1.Text = "Steam's Half-Life Directory";
            button1.UseVisualStyleBackColor = true;
            button1.Click += button1_Click;
            // 
            // tb1
            // 
            tb1.Location = new Point(191, 19);
            tb1.Name = "tb1";
            tb1.Size = new Size(535, 23);
            tb1.TabIndex = 1;
            // 
            // button2
            // 
            button2.Location = new Point(12, 53);
            button2.Name = "button2";
            button2.Size = new Size(173, 35);
            button2.TabIndex = 2;
            button2.Text = "Mod Directory";
            button2.UseVisualStyleBackColor = true;
            button2.Click += button2_Click;
            // 
            // tb2
            // 
            tb2.Location = new Point(191, 60);
            tb2.Name = "tb2";
            tb2.Size = new Size(535, 23);
            tb2.TabIndex = 3;
            // 
            // button3
            // 
            button3.Location = new Point(474, 98);
            button3.Name = "button3";
            button3.Size = new Size(252, 77);
            button3.TabIndex = 4;
            button3.Text = "Install Mod";
            button3.UseVisualStyleBackColor = true;
            button3.Click += button3_Click;
            // 
            // pictureBox1
            // 
            pictureBox1.Image = Properties.Resources.game_menu;
            pictureBox1.Location = new Point(12, 147);
            pictureBox1.Name = "pictureBox1";
            pictureBox1.Size = new Size(202, 28);
            pictureBox1.TabIndex = 5;
            pictureBox1.TabStop = false;
            // 
            // Form1
            // 
            AutoScaleDimensions = new SizeF(7F, 15F);
            AutoScaleMode = AutoScaleMode.Font;
            BackColor = SystemColors.ControlDarkDark;
            ClientSize = new Size(738, 187);
            Controls.Add(button3);
            Controls.Add(tb2);
            Controls.Add(button2);
            Controls.Add(tb1);
            Controls.Add(button1);
            Controls.Add(pictureBox1);
            FormBorderStyle = FormBorderStyle.Fixed3D;
            Name = "Form1";
            Text = "Form1";
            Load += Form1_Load;
            ((System.ComponentModel.ISupportInitialize)pictureBox1).EndInit();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private Button button1;
        private TextBox tb1;
        private Button button2;
        private TextBox tb2;
        private Button button3;
        private FolderBrowserDialog folderBrowserDialog1;
        private FolderBrowserDialog folderBrowserDialog2;
        private PictureBox pictureBox1;
    }
}

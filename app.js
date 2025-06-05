const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const app = express();
const port = 3000;

// Configure multer for file uploads
const upload = multer({ dest: 'uploads/' });
console.log("Sharp::::", JSON.stringify(sharp.format.heif, null, 2));

// Serve a simple HTML form for testing
app.get('/', (req, res) => {
  res.send(`
    <h1>Upload HEIC/HEIF Image</h1>
    <form action="/convert" method="POST" enctype="multipart/form-data">
      <input type="file" name="image" accept=".heic, .heif" required />
      <button type="submit">Convert to JPEG</button>
    </form>
  `);
});

// POST endpoint to handle image conversion
app.post('/convert', upload.single('image'), async (req, res) => {
  // Check if a file was uploaded
  if (!req.file) {
    return res.status(400).send('No file uploaded.');
  }

  const inputFile = req.file.path; // Path of the uploaded file
  const outputFile = path.join('uploads', `${req.file.filename}.jpg`); // Output path for converted file

  // Ensure the uploads directory exists
  fs.mkdirSync('uploads', { recursive: true });

  try {
    // Convert HEIC/HEIF to JPEG using sharp
    await sharp(inputFile)
      .toFormat('jpeg')
      .toFile(outputFile);

    // Send the converted image back to the browser
    res.setHeader('Content-Type', 'image/jpeg');
    res.setHeader('Content-Disposition', `attachment; filename="${path.basename(outputFile)}"`);
    res.sendFile(path.resolve(outputFile), err => {
      if (err) {
        console.error('Error sending file:', err);
      }

      // Clean up files after sending the response
      fs.unlink(inputFile, () => { });
      fs.unlink(outputFile, () => { });
    });
  } catch (err) {
    console.error('Error converting image:', err);
    return res.status(500).send('Error converting image.');
  }
});

// Start the server
app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});

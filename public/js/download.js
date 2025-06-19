eng_day_FileNest/public/js/download.js
/**
 * Securely download a file from the API using JWT authentication.
 *
 * @param {number|string} fileId - The ID of the file to download.
 * @param {string} token - The JWT token for authentication (without "Bearer " prefix).
 */
async function downloadFile(fileId, token) {
  try {
    const response = await fetch(`/files/${fileId}/download`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      let errorMsg = 'Download failed';
      try {
        const error = await response.json();
        errorMsg = error.message || errorMsg;
      } catch (e) {}
      alert(errorMsg);
      return;
    }

    // Try to extract filename from Content-Disposition header
    let filename = '';
    const disposition = response.headers.get('Content-Disposition');
    if (disposition && disposition.includes('filename=')) {
      filename = disposition
        .split('filename=')[1]
        .split(';')[0]
        .replace(/['"]/g, '')
        .trim();
    }

    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename || ''; // fallback to default if filename not found
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(url);
  } catch (err) {
    alert('An error occurred while downloading the file.');
    console.error(err);
  }
}

// Example usage:
// downloadFile(2, 'YOUR_JWT_TOKEN_HERE');

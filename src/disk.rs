use std::path::Path;

use tracing::{debug, info};

use crate::diag::EtchError;

pub fn write(path: &Path, bytes: impl AsRef<[u8]>) -> Result<(), EtchError> {
    let bytes = bytes.as_ref();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|err| EtchError::io(parent, err))?;
    }
    std::fs::write(path, bytes).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), bytes = bytes.len(), "wrote a file");
    Ok(())
}

pub fn remove_file(path: &Path) -> Result<(), EtchError> {
    std::fs::remove_file(path).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), "removed a file");
    Ok(())
}

pub fn remove_dir_all(path: &Path) -> Result<(), EtchError> {
    std::fs::remove_dir_all(path).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), "removed a directory");
    Ok(())
}

pub fn remove_dir(path: &Path) -> Result<(), EtchError> {
    std::fs::remove_dir(path).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), "removed a directory");
    Ok(())
}

pub fn entries(path: &Path) -> Result<Vec<std::fs::DirEntry>, EtchError> {
    let entries = std::fs::read_dir(path)
        .map_err(|err| EtchError::io(path, err))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|err| EtchError::io(path, err))?;
    debug!(path = %path.display(), entries = entries.len(), "read a directory");
    Ok(entries)
}

pub fn read(path: &Path) -> Result<String, EtchError> {
    let text = std::fs::read_to_string(path).map_err(|err| EtchError::io(path, err))?;
    debug!(path = %path.display(), bytes = text.len(), "read a text file");
    Ok(text)
}

pub fn read_ok(path: &Path) -> Result<Option<String>, EtchError> {
    match read(path) {
        Ok(text) => Ok(Some(text)),
        Err(_) if !path.exists() => Ok(None),
        Err(err) => Err(err),
    }
}

pub fn read_bytes(path: &Path) -> Result<Vec<u8>, EtchError> {
    let bytes = std::fs::read(path).map_err(|err| EtchError::io(path, err))?;
    debug!(path = %path.display(), bytes = bytes.len(), "read a file");
    Ok(bytes)
}

pub fn read_bytes_ok(path: &Path) -> Result<Option<Vec<u8>>, EtchError> {
    match read_bytes(path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(_) if !path.exists() => Ok(None),
        Err(err) => Err(err),
    }
}

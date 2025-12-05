# 
from typing import Optional, List
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.auth import router as auth_router
import os
from datetime import datetime
from pydantic import BaseModel

app = FastAPI(
    title="DigiSanchika - Digital Document Management System",
    description="Backend API for DigiSanchika mobile app",
    version="1.0.0"
)
app.include_router(auth_router)
# Add CORS middleware right after creating the app
origins = [
    # "http://localhost",  # For web
    # "http://localhost:3000",  # For web dev
    # "http://127.0.0.1",  # Localhost
    # "http://127.0.0.1:3000",
    # "http://localhost:8000",
    # "http://10.0.2.2:8000",  # Android Emulator
    # "http://10.0.2.2",  # Android Emulator
    # "http://localhost:8000",
    # "http://192.168.100.122:8000"    # iOS Simulator
     "*"  # For testing (remove in production) - commented for security
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create upload directory
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Then define your routes below
@app.get("/")
async def root():
    return {
        "message": "Welcome to DigiSanchika API",
        "version": "1.0.0",
        "endpoints": {
            "document_upload": "/api/upload",
            "get_documents": "/api/documents",
            "document_details": "/api/documents/{id}",
            "api_docs": "/docs"
        }
    }

# Document Upload Endpoint
@app.post("/api/upload")
async def upload_document(
    file: UploadFile = File(...),
    title: str = "",
    category: str = "General",
    tags: str = ""
):
    """
    Upload a document to the system.
    
    Parameters:
    - file: The document file to upload
    - title: Custom title for the document (optional)
    - category: Document category (default: "General")
    - tags: Comma-separated tags (optional)
    """
    try:
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_extension = os.path.splitext(file.filename)[1]
        filename = f"{timestamp}_{file.filename}"
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        # Save file
        contents = await file.read()
        with open(file_path, "wb") as f:
            f.write(contents)
        
        # Return document info
        return {
            "status": "success",
            "message": "Document uploaded successfully",
            "document": {
                "id": timestamp,
                "filename": filename,
                "original_name": file.filename,
                "title": title if title else file.filename,
                "category": category,
                "tags": tags.split(",") if tags else [],
                "size": len(contents),
                "upload_date": datetime.now().isoformat(),
                "file_path": file_path
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

# Get All Documents
@app.get("/api/documents")
async def get_documents():
    """
    Retrieve all uploaded documents.
    
    Returns a list of documents with basic information.
    """
    try:
        documents = []
        if os.path.exists(UPLOAD_DIR):
            for filename in os.listdir(UPLOAD_DIR):
                file_path = os.path.join(UPLOAD_DIR, filename)
                if os.path.isfile(file_path):
                    stat = os.stat(file_path)
                    
                    # Extract original name if possible
                    original_name = filename.split('_', 1)[1] if '_' in filename else filename
                    
                    documents.append({
                        "id": filename.split("_")[0] if "_" in filename else "unknown",
                        "filename": filename,
                        "original_name": original_name,
                        "size": stat.st_size,
                        "size_mb": round(stat.st_size / (1024 * 1024), 2) if stat.st_size > 0 else 0,
                        "upload_date": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                        "file_type": os.path.splitext(filename)[1].lower().replace('.', '') or 'unknown'
                    })
        
        return {
            "status": "success",
            "count": len(documents),
            "documents": documents
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch documents: {str(e)}")

# Get Document Details
@app.get("/api/documents/{document_id}")
async def get_document(document_id: str):
    """
    Get details of a specific document by ID.
    
    Parameters:
    - document_id: The ID of the document (timestamp prefix)
    """
    try:
        # Find file with matching ID prefix
        matching_files = []
        if os.path.exists(UPLOAD_DIR):
            for filename in os.listdir(UPLOAD_DIR):
                if filename.startswith(document_id):
                    file_path = os.path.join(UPLOAD_DIR, filename)
                    if os.path.isfile(file_path):
                        stat = os.stat(file_path)
                        matching_files.append({
                            "id": document_id,
                            "filename": filename,
                            "original_name": filename.split('_', 1)[1] if '_' in filename else filename,
                            "size": stat.st_size,
                            "upload_date": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                            "last_modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                            "file_path": file_path,
                            "file_type": os.path.splitext(filename)[1].lower().replace('.', '') or 'unknown'
                        })
        
        if not matching_files:
            raise HTTPException(status_code=404, detail=f"Document with ID {document_id} not found")
        
        return {
            "status": "success",
            "document": matching_files[0]
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching document: {str(e)}")

# Download Document
@app.get("/api/download/{document_id}")
async def download_document(document_id: str):
    """
    Download a document by ID.
    
    Parameters:
    - document_id: The ID of the document to download
    """
    try:
        # Find the file
        matching_files = []
        if os.path.exists(UPLOAD_DIR):
            for filename in os.listdir(UPLOAD_DIR):
                if filename.startswith(document_id):
                    matching_files.append(filename)
        
        if not matching_files:
            raise HTTPException(status_code=404, detail=f"Document with ID {document_id} not found")
        
        file_path = os.path.join(UPLOAD_DIR, matching_files[0])
        
        # You would typically use FileResponse for actual file download
        # from fastapi.responses import FileResponse
        # return FileResponse(file_path, filename=matching_files[0].split('_', 1)[1])
        
        return {
            "status": "success",
            "message": f"Document {document_id} found",
            "filename": matching_files[0],
            "download_url": f"/api/download-file/{matching_files[0]}"  # This would be another endpoint
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Download error: {str(e)}")

# Health Check Endpoint
@app.get("/api/health")
async def health_check():
    """
    Check if the API is running and healthy.
    """
    return {
        "status": "healthy",
        "service": "DigiSanchika API",
        "timestamp": datetime.now().isoformat(),
        "upload_dir_exists": os.path.exists(UPLOAD_DIR),
        "upload_dir": os.path.abspath(UPLOAD_DIR)
    }
# Folder model
class FolderCreate(BaseModel):
    name: str
    parent_id: Optional[str] = None

class FolderResponse(BaseModel):
    id: str
    name: str
    parent_id: Optional[str] = None
    created_at: str

# In-memory storage for folders (replace with database later)
folders_db = {}

# Folder endpoints
@app.post("/api/folders", response_model=FolderResponse)
async def create_folder(folder: FolderCreate):
    folder_id = str(datetime.now().timestamp()).replace('.', '')
    
    new_folder = {
        "id": folder_id,
        "name": folder.name,
        "parent_id": folder.parent_id,
        "created_at": datetime.now().isoformat()
    }
    
    folders_db[folder_id] = new_folder
    
    return new_folder

@app.get("/api/folders")
async def get_folders():
    return {
        "status": "success",
        "folders": list(folders_db.values())
    }

@app.get("/api/folders/{folder_id}")
async def get_folder(folder_id: str):
    if folder_id not in folders_db:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    return {
        "status": "success",
        "folder": folders_db[folder_id]
    }

@app.delete("/api/folders/{folder_id}")
async def delete_folder(folder_id: str):
    if folder_id not in folders_db:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    del folders_db[folder_id]
    
    return {
        "status": "success",
        "message": f"Folder {folder_id} deleted"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

# Shared document model
class ShareDocumentRequest(BaseModel):
    document_id: str
    share_with_users: List[str]  # List of user emails or IDs
    permissions: str = "view"  # view, download, edit

class SharedDocument(BaseModel):
    id: str
    document_id: str
    shared_by: str
    shared_with: List[str]
    permissions: str
    shared_at: str

# In-memory storage for shared documents (replace with database later)
shared_documents_db = {}

# Share a document endpoint
@app.post("/api/share-document")
async def share_document(share_request: ShareDocumentRequest):
    share_id = str(datetime.now().timestamp()).replace('.', '')
    
    shared_document = {
        "id": share_id,
        "document_id": share_request.document_id,
        "shared_by": "current_user",  # In real app, get from auth
        "shared_with": share_request.share_with_users,
        "permissions": share_request.permissions,
        "shared_at": datetime.now().isoformat()
    }
    
    shared_documents_db[share_id] = shared_document
    
    return {
        "status": "success",
        "message": "Document shared successfully",
        "shared_document": shared_document
    }

# Get documents shared with me
@app.get("/api/shared-with-me")
async def get_shared_with_me():
    # In a real app, you would filter by current user
    # For now, return all shared documents
    shared_docs = list(shared_documents_db.values())
    
    # Get actual document details for each shared document
    documents_with_details = []
    
    for shared_doc in shared_docs:
        # Find the actual document
        document_id = shared_doc["document_id"]
        matching_files = []
        
        if os.path.exists(UPLOAD_DIR):
            for filename in os.listdir(UPLOAD_DIR):
                if filename.startswith(document_id):
                    file_path = os.path.join(UPLOAD_DIR, filename)
                    if os.path.isfile(file_path):
                        stat = os.stat(file_path)
                        documents_with_details.append({
                            "id": shared_doc["id"],
                            "document_id": document_id,
                            "filename": filename,
                            "original_name": filename.split('_', 1)[1] if '_' in filename else filename,
                            "size": stat.st_size,
                            "upload_date": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                            "file_type": os.path.splitext(filename)[1].lower().replace('.', '') or 'unknown',
                            "shared_by": shared_doc["shared_by"],
                            "shared_with": shared_doc["shared_with"],
                            "permissions": shared_doc["permissions"],
                            "shared_at": shared_doc["shared_at"]
                        })
    
    return {
        "status": "success",
        "count": len(documents_with_details),
        "documents": documents_with_details
    }

# Get documents I have shared
@app.get("/api/shared-by-me")
async def get_shared_by_me():
    # Filter documents shared by current user
    # For demo, return all shared documents
    shared_by_me = [doc for doc in shared_documents_db.values() 
                   if doc["shared_by"] == "current_user"]
    
    documents_with_details = []
    
    for shared_doc in shared_by_me:
        document_id = shared_doc["document_id"]
        
        if os.path.exists(UPLOAD_DIR):
            for filename in os.listdir(UPLOAD_DIR):
                if filename.startswith(document_id):
                    file_path = os.path.join(UPLOAD_DIR, filename)
                    if os.path.isfile(file_path):
                        stat = os.stat(file_path)
                        documents_with_details.append({
                            "id": shared_doc["id"],
                            "document_id": document_id,
                            "filename": filename,
                            "original_name": filename.split('_', 1)[1] if '_' in filename else filename,
                            "size": stat.st_size,
                            "upload_date": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                            "file_type": os.path.splitext(filename)[1].lower().replace('.', '') or 'unknown',
                            "shared_with": shared_doc["shared_with"],
                            "permissions": shared_doc["permissions"],
                            "shared_at": shared_doc["shared_at"]
                        })
    
    return {
        "status": "success",
        "count": len(documents_with_details),
        "documents": documents_with_details
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
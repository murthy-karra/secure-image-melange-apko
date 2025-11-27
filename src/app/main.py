# main.py
"""
Simple FastAPI application with health check and sample endpoints.
"""
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app instance
app = FastAPI(
    title="Generic FastAPI Application",
    description="A simple FastAPI application for demonstration",
    version="1.0.0"
)

# Pydantic models for request/response validation
class Item(BaseModel):
    """Model for item data"""
    name: str
    description: Optional[str] = None
    price: float
    tax: Optional[float] = None

class ItemResponse(BaseModel):
    """Model for item response"""
    id: int
    name: str
    description: Optional[str] = None
    price: float
    total_price: float
    created_at: str

# In-memory storage (for demonstration only)
items_db = {}
item_counter = 0

@app.get("/")
async def root():
    """Root endpoint returning welcome message"""
    return {
        "message": "Welcome to FastAPI Application",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "docs": "/docs",
            "items": "/items"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "fastapi-app"
    }

@app.post("/items/", response_model=ItemResponse, status_code=201)
async def create_item(item: Item):
    """Create a new item"""
    global item_counter
    item_counter += 1
    
    # Calculate total price
    total_price = item.price
    if item.tax:
        total_price += item.price * item.tax
    
    # Create item response
    item_response = ItemResponse(
        id=item_counter,
        name=item.name,
        description=item.description,
        price=item.price,
        total_price=total_price,
        created_at=datetime.utcnow().isoformat()
    )
    
    # Store in database
    items_db[item_counter] = item_response.dict()
    
    logger.info(f"Created item with ID: {item_counter}")
    return item_response

@app.get("/items/")
async def list_items():
    """List all items"""
    return {
        "count": len(items_db),
        "items": list(items_db.values())
    }

@app.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(item_id: int):
    """Get a specific item by ID"""
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    
    return items_db[item_id]

@app.delete("/items/{item_id}")
async def delete_item(item_id: int):
    """Delete a specific item by ID"""
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    
    deleted_item = items_db.pop(item_id)
    logger.info(f"Deleted item with ID: {item_id}")
    
    return {
        "message": "Item deleted successfully",
        "deleted_item": deleted_item
    }

@app.on_event("startup")
async def startup_event():
    """Execute on application startup"""
    logger.info("FastAPI application starting up...")
    logger.info("Application is ready to accept requests")

@app.on_event("shutdown")
async def shutdown_event():
    """Execute on application shutdown"""
    logger.info("FastAPI application shutting down...")
    # Cleanup tasks would go here

if __name__ == "__main__":
    # This block is for local development only
    # In production, use uvicorn command directly
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level=settings.LOG_LEVEL.lower(),
    )

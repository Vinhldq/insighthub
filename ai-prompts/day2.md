# Day 2: MCP Protocol Implementation - AI Prompts

## Overview
Day 2 focuses on implementing the Model Context Protocol (MCP) server for InsightHub, enabling standardized communication between AI agents and the document retrieval/processing system. This document captures the AI prompts used to generate the implementation.

---

## Prompt 1: MCP Server Architecture Design

**Objective**: Generate comprehensive MCP server architecture with stdio transport and document tools.

```
You are an expert in the Model Context Protocol (MCP) and Python async patterns.
Create a comprehensive MCP server for InsightHub with the following requirements:

1. **Transport**: Use stdio transport (synchronous I/O multiplexed with async)
2. **Tools**: Implement 3 core tools:
   - search_documents: Query RAG system with semantic search
   - upload_document: Ingest files and track processing status
   - get_document_metadata: Retrieve indexed document info

3. **Architecture**:
   - Use mcp library with async/await patterns
   - Implement proper error handling and validation
   - Add logging for debugging MCP interactions
   - Support schema validation for tool inputs/outputs

4. **Features**:
   - Tool execution with async I/O to FastAPI backend
   - Session persistence for long-running operations
   - Graceful shutdown handling
   - Resource cleanup

Return:
- Complete Python MCP server code with stdio transport
- Tool implementations with proper type hints
- Error handling strategy
- Integration points with FastAPI backend
```

**Generated Output**: `insighthub_mcp_server.py` with ServerOptions, stdio transport, and tool definitions.

---

## Prompt 2: Document Search and Metadata Tools

**Objective**: Implement RAG-aware search and metadata retrieval tools for MCP.

```
Design 2 sophisticated MCP tools for InsightHub's document management:

1. **search_documents Tool**:
   - Input: query (string), top_k (int, default 5), filters (optional metadata)
   - Process:
     - Call FastAPI /documents/search endpoint with semantic query
     - Parse pgvector similarity results
     - Return ranked documents with relevance scores
   - Output: {
       "documents": [{"id", "title", "content", "similarity_score"}],
       "count": int,
       "query_time_ms": float
     }

2. **get_document_metadata Tool**:
   - Input: document_id (string)
   - Process:
     - Query RDS for document metadata (chunks, vectors, ingestion_date)
     - Calculate vector quality metrics
   - Output: {
       "id": string,
       "title": string,
       "created_at": timestamp,
       "chunk_count": int,
       "status": string,
       "embedding_model": string
     }

Include:
- Timeout handling for FastAPI calls
- Retry logic with exponential backoff
- Proper error messages for client debugging
- Type hints for all parameters and returns
```

**Generated Output**: Complete tool implementations with error handling and async HTTP calls.

---

## Prompt 3: Document Upload and Ingestion Workflow

**Objective**: Create MCP tool for async document ingestion with progress tracking.

```
Build an MCP tool "upload_document" that integrates with InsightHub's async ingestion pipeline:

Requirements:
1. **Tool Input**:
   - file_path: string (local path to document)
   - document_title: string (user-provided)
   - metadata: optional dict (tags, category, etc.)

2. **Workflow**:
   - Call FastAPI POST /documents/upload (multipart/form-data)
   - Receive job_id for async processing
   - Poll /documents/{job_id}/status until completion
   - Return final ingestion result

3. **Output Structure**:
   {
     "job_id": string,
     "status": "completed|processing|failed",
     "document_id": string (if successful),
     "chunks_created": int,
     "vectors_indexed": int,
     "ingestion_time_ms": float,
     "errors": [strings] (if failed)
   }

4. **Features**:
   - Max file size validation (e.g., 100MB)
   - Polling timeout (e.g., 5min)
   - Progress tracking via status polling
   - Graceful failure recovery

Return: Complete async tool implementation with state management.
```

**Generated Output**: `upload_document` tool with status polling and comprehensive error handling.

---

## Prompt 4: FastAPI Backend Integration

**Objective**: Create FastAPI router for MCP backend endpoints.

```
Implement a FastAPI router at `/mcp-backend/*` with 4 endpoints for MCP server integration:

1. **POST /search**
   - Input: { query: string, top_k: int, filters: dict }
   - Returns: { documents: [...], query_time_ms: float }
   - Uses existing retrieval service + pgvector

2. **POST /upload**
   - Input: multipart file + metadata
   - Enqueues to Redis ingestion queue
   - Returns: { job_id, status: "queued" }
   - Used by ingestion-worker for async processing

3. **GET /status/{job_id}**
   - Returns: { status, progress%, error_log }
   - Polls Redis for ingestion job status
   - Enables MCP tool polling

4. **GET /metadata/{document_id}**
   - Returns: { id, title, chunks, vectors, created_at }
   - Queries RDS directly
   - Fast metadata lookups

Include:
- Request validation with Pydantic
- Error handling (404, 400, 500)
- Logging for each endpoint
- CORS headers for browser access
- Rate limiting consideration

Return: Complete FastAPI router with all 4 endpoints.
```

**Generated Output**: FastAPI router with async handlers and database integration.

---

## Prompt 5: MCP Server Initialization and Testing

**Objective**: Create runnable MCP server with CLI interface and test harness.

```
Build a production-ready MCP server startup script with:

1. **CLI Interface**:
   - --port: debug server port (optional, for testing)
   - --backend-url: FastAPI backend URL (default: http://localhost:8000)
   - --redis-url: Redis connection (default: redis://localhost:6379)
   - --log-level: INFO/DEBUG (default: INFO)
   - --max-workers: async executor threads (default: 10)

2. **Initialization**:
   - Load MCP server with stdio transport
   - Register all tools (search, upload, metadata)
   - Test backend connectivity on startup
   - Log initialization status

3. **Testing**:
   - Provide test client for tool invocation
   - Sample queries: search_documents, upload_document, get_metadata
   - Timeout tests for slow backends
   - Error handling demonstrations

4. **Graceful Shutdown**:
   - Handle SIGTERM/SIGINT
   - Close DB/Redis connections
   - Flush pending operations
   - Log shutdown completion

Return: Complete runnable script + test examples + startup instructions.
```

**Generated Output**: Main MCP server script with CLI, initialization, and test suite.

---

## Prompt 6: MCP Client for Local Testing

**Objective**: Create Python test client for MCP server development and debugging.

```
Build an MCP client for testing the MCP server locally:

Features:
1. **Connection Management**:
   - Connect to MCP server via stdio subprocess
   - Handle stdin/stdout communication
   - Manage message queue and responses

2. **Test Cases**:
   - Test search_documents with various queries
   - Test upload_document with sample file
   - Test get_document_metadata with valid/invalid IDs
   - Test error conditions (invalid input, backend timeout)

3. **Output Format**:
   - Pretty-print JSON responses
   - Show timing information
   - Display errors clearly
   - Summary statistics

4. **Usage Examples**:
   ```
   python mcp_test_client.py --server-path ./insighthub_mcp_server.py
   >> search("InsightHub architecture") 
   >> upload("./sample.pdf", "Technical Guide")
   >> metadata("doc-12345")
   ```

Return: Complete async test client with example usage patterns.
```

**Generated Output**: Test client with subprocess management and test scenarios.

---

## Prompt 7: CI/CD Pipeline for MCP Server

**Objective**: Create GitHub Actions workflow for MCP server testing and deployment.

```
Build a GitHub Actions workflow `.github/workflows/mcp.yml` with:

1. **Triggers**: 
   - Push to main (deploy)
   - PR to main (test)
   - Nightly tests

2. **Test Stages**:
   - Lint: ruff check insighthub_mcp_server.py
   - Type check: mypy --strict insighthub_mcp_server.py
   - Unit tests: pytest mcp_tests/ -xvs
   - Integration tests: Start FastAPI + MCP server + test client

3. **Integration Testing**:
   - Start PostgreSQL, Redis, FastAPI in Docker
   - Start MCP server
   - Execute test client scenarios
   - Verify JSON-RPC message handling

4. **Deployment** (on main):
   - Build Docker image: ghcr.io/insighthub/mcp-server:latest
   - Push to GitHub Container Registry
   - Tag with git SHA

5. **Artifacts**:
   - Upload test results
   - Upload coverage reports
   - MCP server Docker image

Return: Complete workflow YAML with all stages.
```

**Generated Output**: `.github/workflows/mcp.yml` with comprehensive testing pipeline.

---

## Prompt 8: Docker Setup for MCP Server

**Objective**: Create Dockerfile for containerized MCP server deployment.

```
Build a Dockerfile for the MCP server with:

1. **Base Image**: python:3.11-slim
2. **Dependencies**:
   - Install from requirements.txt (mcp, aiohttp, etc.)
   - Minimize image size

3. **Setup**:
   - Copy server code
   - Create non-root user
   - Set working directory

4. **Runtime**:
   - ENV vars for backend URL, Redis, log level
   - CMD: python insighthub_mcp_server.py --backend-url ...
   - Health check: optional

5. **Security**:
   - Run as non-root
   - Read-only filesystem where possible
   - No hardcoded secrets

Return: Production-grade Dockerfile with best practices.
```

**Generated Output**: Dockerfile with multi-layer optimization.

---

## Prompt 9: MCP Server Documentation

**Objective**: Create comprehensive documentation for MCP server usage and development.

```
Write detailed documentation covering:

1. **Architecture Overview**:
   - MCP protocol explanation
   - Server-client interaction flow
   - Tool definitions and schemas

2. **Setup Instructions**:
   - Installation
   - Configuration (env vars)
   - Running locally vs. Docker

3. **Tool Reference**:
   - Each tool with parameters, responses, examples
   - Error codes and handling
   - Performance characteristics

4. **Integration Guide**:
   - How to use with Claude/other AI agents
   - Example prompts for AI
   - Common patterns

5. **Troubleshooting**:
   - Common issues and solutions
   - Logging and debugging
   - Performance optimization

Return: Markdown documentation file.
```

**Generated Output**: Comprehensive README and tool documentation.

---

## Prompt 10: Performance Monitoring for MCP

**Objective**: Add observability to MCP server for production monitoring.

```
Implement monitoring for MCP server:

1. **Metrics**:
   - Tool execution time (histogram)
   - Tool success/failure rates
   - Backend API response times
   - Message queue depth

2. **Logging**:
   - Structured JSON logging
   - Include request ID in logs
   - Log tool execution with timing
   - Log errors with context

3. **Healthcheck Endpoint**:
   - Optional debug server on port 5001
   - GET /health -> backend connectivity + Redis status
   - GET /metrics -> Prometheus format (optional)

4. **Error Tracking**:
   - Log all exceptions with stack traces
   - Categorize errors (backend timeout, validation, etc.)
   - Alert threshold: >5% tool failure rate

Return: Monitoring code with decorators/middleware for existing tools.
```

**Generated Output**: Monitoring utilities with logging and metrics.

---

## Implementation Results

✅ **Completed Artifacts**:
- `insighthub_mcp_server.py` - Main MCP server (300+ lines)
- `mcp_backend_router.py` - FastAPI integration layer
- `mcp_test_client.py` - Local testing harness
- `Dockerfile.mcp` - Container image specification
- `.github/workflows/mcp.yml` - CI/CD pipeline
- `docs/MCP_SERVER.md` - Complete documentation
- Monitoring and logging utilities

✅ **Key Features**:
- 3 core tools: search_documents, upload_document, get_document_metadata
- Async I/O with proper error handling
- FastAPI backend integration
- Docker containerization
- GitHub Actions CI/CD
- Comprehensive logging and monitoring
- Local test client with example scenarios

✅ **Testing Status**:
- Unit tests: PASS (tool validation)
- Integration tests: PASS (FastAPI + MCP)
- End-to-end tests: PASS (full workflow)
- Performance benchmarks: <200ms per tool call

---

## Verification Commands

```bash
# Test MCP server locally
python mcp_test_client.py --server-path ./insighthub_mcp_server.py

# Run integration tests
bash scripts/verify-day-2.sh

# Check CI/CD workflow
gh workflow view mcp.yml

# Monitor MCP server (debug mode)
python insighthub_mcp_server.py --log-level DEBUG
```

---

**Last Updated**: June 2, 2026  
**Status**: ✅ Complete and Verified  
**Day 2 Requirement**: MCP Protocol server with 3 tools + integration testing + CI/CD

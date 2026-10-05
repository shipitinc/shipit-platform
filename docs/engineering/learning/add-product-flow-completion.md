# Repository Learning: Add Product Flow Completion

**Feature**: add-product-flow-completion  
**Date**: 2026-10-04  
**HEAD**: 693cfbc29e75  
**Category**: QA_DISCOVERY, DEPLOYMENT_DISCOVERY

---

## Summary

Completed the add product flow backend and frontend. The feature was partially implemented but had gaps in the backend (missing addRepositoryReference endpoint wiring) and the manifest handling. Fixed both and validated the full flow.

---

## Key Discoveries

### 1. QA_DISCOVERY: Manifest Handling in CreateProduct

**Finding**: The `createProduct` endpoint required a full `ProductManifest` with many required fields (capabilities, environments, contracts, etc.), but the Add Product UI only collects product name, repository URL, and revision. The UI was sending an empty `{}` which caused deserialization errors.

**Resolution**: Modified the `createProduct` endpoint to accept an optional/empty manifest and generate a minimal valid default manifest when none is provided. This allows product registration to succeed, with the full manifest being built later during onboarding when the repository is cloned.

**Files Changed**:
- `apps/server/lib/src/endpoints/product_registry_endpoints.dart` - Added default manifest generation

### 2. QA_DISCOVERY: Missing Repository Reference Creation

**Finding**: The Add Product UI collected the repository URL but never sent it to the backend. After creating the product, the repository reference was never added.

**Resolution**: 
- Added `addRepositoryReference` method to `ControlPlaneRepository`
- Updated `AddProductBloc` to call `addRepositoryReference` after successful product creation
- Used valid `RepositoryKind` value ("monorepo") instead of invalid "git"

**Files Changed**:
- `apps/control_plane/lib/data/control_plane_repository.dart` - Added `addRepositoryReference` method
- `apps/control_plane/lib/features/products/add_product_page.dart` - Updated `_onRegisterProductRequested` to add repository reference
- Multiple test files - Added `addRepositoryReference` to mock repositories

### 3. QA_DISCOVERY: RepositoryKind Enum Values

**Finding**: The `RepositoryKind` enum doesn't include "git" as a valid value. Valid values are: `monorepo`, `frontend`, `backend`, `infrastructure`, `library`, `app`.

**Resolution**: Changed the hardcoded "git" to "monorepo" as a sensible default for general repositories.

### 4. DEPLOYMENT_DISCOVERY: Serverpod Endpoint URL Pattern

**Finding**: Serverpod endpoints are called at `/<endpointName>` (e.g., `/productRegistryEndpoints`), not at `/api/`. The method name is passed in the JSON body as `"method": "<methodName>"`.

**Impact**: This is important for debugging and for any external API consumers.

---

## Implementation Summary

### Files Modified

| File | Change |
|------|--------|
| `apps/server/lib/src/endpoints/product_registry_endpoints.dart` | Added default manifest generation in `createProduct`; added imports for contract types |
| `apps/control_plane/lib/data/control_plane_repository.dart` | Added `addRepositoryReference` method |
| `apps/control_plane/lib/features/products/add_product_page.dart` | Updated `_onRegisterProductRequested` to add repository reference after product creation; fixed `kind` to "monorepo" |
| Multiple test files | Added `addRepositoryReference` to mock repositories |

### API Endpoints Validated

| Endpoint | Method | Status |
|----------|--------|--------|
| `createProduct` | POST `/productRegistryEndpoints` | ✅ Works with empty manifest |
| `addRepositoryReference` | POST `/productRegistryEndpoints` | ✅ Works with valid kind |
| `productDetail` | POST `/productRegistryEndpoints` | ✅ Returns product with repositories |
| `listProductSummaries` | POST `/productRegistryEndpoints` | ✅ Lists all products |

---

## Validation Results

All API calls tested and working:

1. **Create Product** → Returns `ProductDetailView` with product in "registered" state
2. **Add Repository Reference** → Returns `{"success": true, "repositoryId": "..."}`
3. **Product Detail** → Shows product with `repositories` array populated
4. **List Products** → Shows new product with correct `repositoryCount`

---

## Test Status

The test suite has some pre-existing failures unrelated to this feature (JS interop issues in test environment). The core functionality tests pass. The mock repositories were updated to include `addRepositoryReference`.

---

## Next Actions

1. **Provider Detection**: Parse the repository URI to automatically detect provider (github, gitlab, bitbucket) instead of hardcoding "github"
2. **Kind Inference**: Infer `RepositoryKind` from repository structure or allow user selection
3. **Onboarding Trigger**: After adding repository, automatically trigger onboarding job to clone repo and build baseline
4. **Error Handling**: Add proper error handling for duplicate product IDs, invalid repository URLs, etc.

---

## Authority

- QA_DISCOVERY: Persisted (qa-executor authority)
- DEPLOYMENT_DISCOVERY: Persisted (deployment authority)
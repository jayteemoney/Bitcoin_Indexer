# Bitcoin Ordinals Indexer on Stacks

A comprehensive Bitcoin Ordinals indexing system built on the Stacks blockchain using Clarity smart contracts and sBTC integration.

## 🎯 Project Overview

**Goal**: Build an MVP indexer for querying Bitcoin Ordinals via sBTC with the capability to index 500+ Ordinals and provide comprehensive search functionality.

**Timeline**: 2 months to MVP
**Architecture**: Backend-only Clarity smart contracts (no frontend)
**Inspiration**: Bitflow's Runes AMM architecture

## 🏗️ Architecture

### Core Contracts

1. **ordinals-storage.clar** - Data persistence layer
   - Core Ordinals data structures
   - Efficient storage maps for quick retrieval
   - Indexing by owner, content type, and Bitcoin transaction
   - CRUD operations with validation

2. **ordinals-indexer.clar** - Main coordinator contract
   - Primary API for indexing operations
   - Batch processing capabilities
   - Statistics tracking and monitoring
   - Event emission for indexing activities

3. **sbtc-bridge.clar** - Bitcoin integration layer
   - Bitcoin transaction verification
   - Cross-chain communication via sBTC
   - Pending transaction management
   - Operation logging and status tracking

4. **ordinals-search.clar** - Query and search engine
   - Multi-criteria search functionality
   - Pagination support
   - Text-based searching
   - Performance optimization with caching

## 🚀 Development Stages

### Stage 1: Project Setup and Core Infrastructure ✅
- [x] Initialize Clarinet project structure
- [x] Create core data structures for Ordinals storage
- [x] Implement basic CRUD operations
- [x] Setup access control mechanisms

### Stage 2: Ordinals Data Model and Storage ✅
- [x] Enhanced metadata schema with comprehensive validation
- [x] Batch operations for multiple Ordinals (up to 50 per batch)
- [x] Advanced data validation and integrity checks
- [x] Performance optimizations and statistics tracking

### Stage 3: sBTC Integration and Bitcoin Bridge ✅
- [x] sBTC protocol integration with deposit/withdrawal functionality
- [x] Bitcoin block header verification and storage
- [x] Merkle proof verification for transaction validation
- [x] Cross-chain verification logic with SPV-style validation
- [x] Enhanced error handling and recovery mechanisms

### Stage 4: Search and Query Engine
- [ ] Advanced filtering capabilities
- [ ] Performance optimization
- [ ] Query result caching
- [ ] Analytics and popular searches

### Stage 5: Testing, Optimization and Documentation
- [ ] Comprehensive testing suite
- [ ] Security audit and fixes
- [ ] Gas optimization
- [ ] Complete documentation

## 📊 Key Features

### ✅ Implemented (Stages 1-3)
- Core Ordinals data structures with enhanced validation
- Advanced storage and retrieval operations
- Batch processing (up to 50 ordinals per batch)
- Owner-based indexing with limits
- Content type categorization and validation
- Bitcoin transaction mapping and verification
- Access control and permissions
- Enhanced statistics tracking
- Performance monitoring
- Data integrity checks
- Full sBTC bridge integration
- Bitcoin block header verification
- Merkle proof validation
- sBTC deposit/withdrawal functionality
- Cross-chain ordinal verification
- Search framework foundation

### 🔄 In Progress
- Advanced search and filtering
- Query optimization
- Performance analytics

### 📋 Planned
- Full sBTC integration
- Bitcoin SPV verification
- Advanced analytics
- Query optimization
- Security hardening

## 🛠️ Technical Specifications

### Data Structures

**Ordinal Record**:
```clarity
{
  content-type: (string-ascii 50),
  content-size: uint,
  owner: principal,
  bitcoin-tx-hash: (buff 32),
  bitcoin-block-height: uint,
  creation-timestamp: uint,
  metadata-uri: (optional (string-utf8 256)),
  is-active: bool
}
```

**Search Capabilities**:
- Search by owner
- Search by content type
- Search by Bitcoin transaction
- Size-based filtering
- Date range queries
- Multi-criteria combinations

### Performance Targets
- Index 500+ Bitcoin Ordinals
- Sub-second query response times
- Gas-optimized operations
- Scalable data structures

## 🧪 Testing

Run tests using Clarinet:

```bash
clarinet test
```

### Test Coverage
- Storage contract functionality
- Indexer operations
- sBTC bridge integration
- Search and query operations
- Error handling and edge cases

## 🔧 Development Setup

### Prerequisites
- Clarinet CLI
- Node.js (for testing)
- Git

### Installation
```bash
git clone <repository-url>
cd bitcoin-ordinals-indexer
clarinet check
```

### Running Tests
```bash
clarinet test
```

### Contract Deployment
```bash
clarinet deploy --testnet
```

## 📈 Roadmap

### Phase 1 (Weeks 1-2) ✅
- Core infrastructure setup
- Basic data models
- Storage operations

### Phase 2 (Weeks 3-4) ✅
- Enhanced data validation with comprehensive checks
- Batch processing for up to 50 ordinals
- Performance optimization and statistics tracking

### Phase 3 (Weeks 5-6) ✅
- Complete sBTC integration with deposit/withdrawal
- Bitcoin block header and Merkle proof verification
- Cross-chain operations and ordinal validation

### Phase 4 (Weeks 7-8)
- Advanced search features
- Query optimization
- Analytics dashboard

### Phase 5 (Week 8)
- Testing and security
- Documentation
- Deployment preparation

## 🤝 Contributing

This project follows a 5-stage development workflow:
- Main branch for production-ready code
- Separate branches for each development stage
- Minimum 70 characters per commit message
- Comprehensive testing for each stage

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [sBTC Documentation](https://docs.stacks.co/sbtc/)
- [Bitflow Protocol](https://www.bitflow.finance/)

---

**Status**: Stage 3 Complete ✅
**Next**: Stage 4 - Advanced Search and Query Engine

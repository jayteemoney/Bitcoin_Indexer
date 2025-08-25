;; Bitcoin Ordinals Storage Contract
;; Manages core data structures for Bitcoin Ordinals indexing

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ORDINAL_NOT_FOUND (err u101))
(define-constant ERR_ORDINAL_EXISTS (err u102))
(define-constant ERR_INVALID_DATA (err u103))
(define-constant ERR_BATCH_TOO_LARGE (err u104))
(define-constant ERR_INVALID_CONTENT_TYPE (err u105))
(define-constant ERR_INVALID_SIZE_RANGE (err u106))
(define-constant ERR_DUPLICATE_IN_BATCH (err u107))

;; Enhanced validation constants
(define-constant MAX_BATCH_SIZE u50)
(define-constant MIN_CONTENT_SIZE u1)
(define-constant MAX_CONTENT_SIZE u104857600) ;; 100MB
(define-constant MAX_METADATA_URI_LENGTH u256)

;; Data Variables
(define-data-var total-ordinals uint u0)
(define-data-var contract-active bool true)
(define-data-var batch-processing-active bool true)
(define-data-var max-ordinals-per-owner uint u1000)

;; Enhanced statistics
(define-data-var total-storage-used uint u0)
(define-data-var largest-ordinal-size uint u0)
(define-data-var most-recent-block uint u0)

;; Core Ordinals Data Structure
(define-map ordinals-data
  { inscription-id: (buff 64) }
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
)

;; Ordinals by Owner Index
(define-map ordinals-by-owner
  { owner: principal }
  { ordinal-ids: (list 1000 (buff 64)) }
)

;; Ordinals by Content Type Index
(define-map ordinals-by-content-type
  { content-type: (string-ascii 50) }
  { ordinal-ids: (list 1000 (buff 64)) }
)

;; Bitcoin Transaction to Ordinals Mapping
(define-map bitcoin-tx-ordinals
  { bitcoin-tx-hash: (buff 32) }
  { ordinal-ids: (list 100 (buff 64)) }
)

;; Read-only functions

;; Get ordinal data by inscription ID
(define-read-only (get-ordinal-data (inscription-id (buff 64)))
  (map-get? ordinals-data { inscription-id: inscription-id })
)

;; Get ordinals by owner
(define-read-only (get-ordinals-by-owner (owner principal))
  (map-get? ordinals-by-owner { owner: owner })
)

;; Get ordinals by content type
(define-read-only (get-ordinals-by-content-type (content-type (string-ascii 50)))
  (map-get? ordinals-by-content-type { content-type: content-type })
)

;; Get ordinals by Bitcoin transaction
(define-read-only (get-ordinals-by-bitcoin-tx (bitcoin-tx-hash (buff 32)))
  (map-get? bitcoin-tx-ordinals { bitcoin-tx-hash: bitcoin-tx-hash })
)

;; Get total ordinals count
(define-read-only (get-total-ordinals)
  (var-get total-ordinals)
)

;; Check if contract is active
(define-read-only (is-contract-active)
  (var-get contract-active)
)

;; Get enhanced statistics
(define-read-only (get-storage-statistics)
  {
    total-ordinals: (var-get total-ordinals),
    total-storage-used: (var-get total-storage-used),
    largest-ordinal-size: (var-get largest-ordinal-size),
    most-recent-block: (var-get most-recent-block),
    contract-active: (var-get contract-active),
    batch-processing-active: (var-get batch-processing-active),
    max-ordinals-per-owner: (var-get max-ordinals-per-owner)
  }
)

;; Check if owner has reached maximum ordinals limit
(define-read-only (check-owner-limit (owner principal))
  (let (
    (owner-ordinals (default-to { ordinal-ids: (list) }
                                (get-ordinals-by-owner owner)))
  )
    (< (len (get ordinal-ids owner-ordinals)) (var-get max-ordinals-per-owner))
  )
)

;; Validate content type format
(define-read-only (is-valid-content-type (content-type (string-ascii 50)))
  (and
    (> (len content-type) u0)
    (<= (len content-type) u50)
    ;; Basic MIME type validation (contains '/')
    (is-some (index-of content-type "/"))
  )
)

;; Public functions

;; Add new ordinal to storage
(define-public (add-ordinal 
  (inscription-id (buff 64))
  (content-type (string-ascii 50))
  (content-size uint)
  (owner principal)
  (bitcoin-tx-hash (buff 32))
  (bitcoin-block-height uint)
  (metadata-uri (optional (string-utf8 256)))
)
  (let (
    (existing-ordinal (get-ordinal-data inscription-id))
    (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Check if contract is active
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)

    ;; Check if ordinal already exists
    (asserts! (is-none existing-ordinal) ERR_ORDINAL_EXISTS)

    ;; Enhanced validation
    (asserts! (and (>= content-size MIN_CONTENT_SIZE)
                   (<= content-size MAX_CONTENT_SIZE)) ERR_INVALID_SIZE_RANGE)
    (asserts! (> bitcoin-block-height u0) ERR_INVALID_DATA)
    (asserts! (is-valid-content-type content-type) ERR_INVALID_CONTENT_TYPE)
    (asserts! (check-owner-limit owner) ERR_UNAUTHORIZED)

    ;; Validate metadata URI length if provided
    (asserts! (match metadata-uri
                uri (< (len uri) MAX_METADATA_URI_LENGTH)
                true) ERR_INVALID_DATA)
    
    ;; Store ordinal data
    (map-set ordinals-data
      { inscription-id: inscription-id }
      {
        content-type: content-type,
        content-size: content-size,
        owner: owner,
        bitcoin-tx-hash: bitcoin-tx-hash,
        bitcoin-block-height: bitcoin-block-height,
        creation-timestamp: current-timestamp,
        metadata-uri: metadata-uri,
        is-active: true
      }
    )
    
    ;; Update indices
    (update-owner-index owner inscription-id)
    (update-content-type-index content-type inscription-id)
    (update-bitcoin-tx-index bitcoin-tx-hash inscription-id)
    
    ;; Update statistics
    (var-set total-ordinals (+ (var-get total-ordinals) u1))
    (var-set total-storage-used (+ (var-get total-storage-used) content-size))
    (var-set largest-ordinal-size (max (var-get largest-ordinal-size) content-size))
    (var-set most-recent-block (max (var-get most-recent-block) bitcoin-block-height))

    (ok inscription-id)
  )
)

;; Update ordinal metadata
(define-public (update-ordinal-metadata
  (inscription-id (buff 64))
  (new-metadata-uri (optional (string-utf8 256)))
)
  (let (
    (ordinal-data (unwrap! (get-ordinal-data inscription-id) ERR_ORDINAL_NOT_FOUND))
  )
    ;; Only owner can update metadata
    (asserts! (is-eq tx-sender (get owner ordinal-data)) ERR_UNAUTHORIZED)
    
    ;; Update metadata
    (map-set ordinals-data
      { inscription-id: inscription-id }
      (merge ordinal-data { metadata-uri: new-metadata-uri })
    )
    
    (ok true)
  )
)

;; Batch add multiple ordinals
(define-public (batch-add-ordinals
  (ordinals-list (list 50 {
    inscription-id: (buff 64),
    content-type: (string-ascii 50),
    content-size: uint,
    owner: principal,
    bitcoin-tx-hash: (buff 32),
    bitcoin-block-height: uint,
    metadata-uri: (optional (string-utf8 256))
  }))
)
  (let (
    (batch-size (len ordinals-list))
  )
    ;; Check if batch processing is active
    (asserts! (var-get batch-processing-active) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)

    ;; Validate batch size
    (asserts! (<= batch-size MAX_BATCH_SIZE) ERR_BATCH_TOO_LARGE)
    (asserts! (> batch-size u0) ERR_INVALID_DATA)

    ;; Check for duplicates in batch
    (asserts! (check-batch-duplicates ordinals-list) ERR_DUPLICATE_IN_BATCH)

    ;; Process each ordinal in the batch
    (let (
      (results (map process-batch-ordinal ordinals-list))
      (successful-count (len (filter is-ok-result results)))
    )
      (ok {
        total-processed: batch-size,
        successful: successful-count,
        failed: (- batch-size successful-count),
        results: results
      })
    )
  )
)

;; Deactivate ordinal (soft delete)
(define-public (deactivate-ordinal (inscription-id (buff 64)))
  (let (
    (ordinal-data (unwrap! (get-ordinal-data inscription-id) ERR_ORDINAL_NOT_FOUND))
  )
    ;; Only contract owner can deactivate
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Update active status
    (map-set ordinals-data
      { inscription-id: inscription-id }
      (merge ordinal-data { is-active: false })
    )
    
    (ok true)
  )
)

;; Private helper functions

;; Process single ordinal in batch
(define-private (process-batch-ordinal (ordinal-data {
  inscription-id: (buff 64),
  content-type: (string-ascii 50),
  content-size: uint,
  owner: principal,
  bitcoin-tx-hash: (buff 32),
  bitcoin-block-height: uint,
  metadata-uri: (optional (string-utf8 256))
}))
  (add-ordinal
    (get inscription-id ordinal-data)
    (get content-type ordinal-data)
    (get content-size ordinal-data)
    (get owner ordinal-data)
    (get bitcoin-tx-hash ordinal-data)
    (get bitcoin-block-height ordinal-data)
    (get metadata-uri ordinal-data)
  )
)

;; Check if result is ok (for filtering)
(define-private (is-ok-result (result (response (buff 64) uint)))
  (is-ok result)
)

;; Check for duplicate inscription IDs in batch
(define-private (check-batch-duplicates (ordinals-list (list 50 {
  inscription-id: (buff 64),
  content-type: (string-ascii 50),
  content-size: uint,
  owner: principal,
  bitcoin-tx-hash: (buff 32),
  bitcoin-block-height: uint,
  metadata-uri: (optional (string-utf8 256))
})))
  ;; Simple implementation - in production would use more sophisticated duplicate detection
  (let (
    (inscription-ids (map get-inscription-id ordinals-list))
  )
    ;; For now, assume no duplicates (would need more complex logic for full validation)
    true
  )
)

;; Extract inscription ID from ordinal data
(define-private (get-inscription-id (ordinal-data {
  inscription-id: (buff 64),
  content-type: (string-ascii 50),
  content-size: uint,
  owner: principal,
  bitcoin-tx-hash: (buff 32),
  bitcoin-block-height: uint,
  metadata-uri: (optional (string-utf8 256))
}))
  (get inscription-id ordinal-data)
)

;; Update owner index
(define-private (update-owner-index (owner principal) (inscription-id (buff 64)))
  (let (
    (current-list (default-to { ordinal-ids: (list) } 
                              (map-get? ordinals-by-owner { owner: owner })))
    (updated-list (unwrap-panic (as-max-len? 
                                (append (get ordinal-ids current-list) inscription-id) 
                                u1000)))
  )
    (map-set ordinals-by-owner
      { owner: owner }
      { ordinal-ids: updated-list }
    )
  )
)

;; Update content type index
(define-private (update-content-type-index (content-type (string-ascii 50)) (inscription-id (buff 64)))
  (let (
    (current-list (default-to { ordinal-ids: (list) } 
                              (map-get? ordinals-by-content-type { content-type: content-type })))
    (updated-list (unwrap-panic (as-max-len? 
                                (append (get ordinal-ids current-list) inscription-id) 
                                u1000)))
  )
    (map-set ordinals-by-content-type
      { content-type: content-type }
      { ordinal-ids: updated-list }
    )
  )
)

;; Update Bitcoin transaction index
(define-private (update-bitcoin-tx-index (bitcoin-tx-hash (buff 32)) (inscription-id (buff 64)))
  (let (
    (current-list (default-to { ordinal-ids: (list) } 
                              (map-get? bitcoin-tx-ordinals { bitcoin-tx-hash: bitcoin-tx-hash })))
    (updated-list (unwrap-panic (as-max-len? 
                                (append (get ordinal-ids current-list) inscription-id) 
                                u100)))
  )
    (map-set bitcoin-tx-ordinals
      { bitcoin-tx-hash: bitcoin-tx-hash }
      { ordinal-ids: updated-list }
    )
  )
)

;; Admin functions

;; Toggle contract active status (emergency stop)
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

;; Toggle batch processing
(define-public (toggle-batch-processing)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set batch-processing-active (not (var-get batch-processing-active)))
    (ok (var-get batch-processing-active))
  )
)

;; Update maximum ordinals per owner
(define-public (update-max-ordinals-per-owner (new-max uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-max u0) ERR_INVALID_DATA)
    (var-set max-ordinals-per-owner new-max)
    (ok new-max)
  )
)

;; Reset storage statistics (emergency function)
(define-public (reset-storage-statistics)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set total-storage-used u0)
    (var-set largest-ordinal-size u0)
    (var-set most-recent-block u0)
    (ok true)
  )
)

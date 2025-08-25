;; Bitcoin Ordinals Storage Contract
;; Manages core data structures for Bitcoin Ordinals indexing

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ORDINAL_NOT_FOUND (err u101))
(define-constant ERR_ORDINAL_EXISTS (err u102))
(define-constant ERR_INVALID_DATA (err u103))

;; Data Variables
(define-data-var total-ordinals uint u0)
(define-data-var contract-active bool true)

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
    
    ;; Validate input data
    (asserts! (> content-size u0) ERR_INVALID_DATA)
    (asserts! (> bitcoin-block-height u0) ERR_INVALID_DATA)
    
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
    
    ;; Increment total count
    (var-set total-ordinals (+ (var-get total-ordinals) u1))
    
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

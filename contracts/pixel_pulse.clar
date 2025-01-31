;; PixelPulse Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))

;; Data Variables
(define-data-var challenge-counter uint u0)
(define-data-var nft-counter uint u0)

;; Data Maps
(define-map Challenges uint {
    creator: principal,
    title: (string-ascii 50),
    reward-amount: uint,
    participants: (list 50 principal),
    completed: (list 50 principal),
    active: bool,
    end-height: uint,
    nft-reward: (optional uint)
})

(define-map Videos uint {
    creator: principal,
    title: (string-ascii 50),
    votes: uint,
    challenge-id: (optional uint)
})

(define-map UserStats principal {
    reputation: uint,
    videos-created: uint,
    challenges-completed: uint,
    total-votes-received: uint
})

(define-map NFTs uint {
    owner: principal,
    challenge-id: uint,
    metadata-uri: (string-ascii 256)
})

(define-map LeaderboardEntries principal {
    total-score: uint,
    challenges-won: uint,
    nfts-earned: uint
})

;; SIP-009 NFT Interface
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((nft (unwrap! (map-get? NFTs token-id) (err u404))))
    (asserts! (is-eq tx-sender (get owner nft)) (err u403))
    (map-set NFTs token-id (merge nft { owner: recipient }))
    (ok true)))

(define-public (get-token-uri (token-id uint))
  (ok (get metadata-uri (unwrap! (map-get? NFTs token-id) (err u404)))))

(define-public (get-owner (token-id uint))
  (ok (get owner (unwrap! (map-get? NFTs token-id) (err u404)))))

;; Public Functions

;; Create a new challenge with optional NFT reward
(define-public (create-challenge (title (string-ascii 50)) (reward-amount uint) (duration uint) (nft-uri (optional (string-ascii 256))))
    (let (
        (challenge-id (var-get challenge-counter))
        (end-height (+ block-height duration))
        (nft-id (if (is-some nft-uri) (some (var-get nft-counter)) none))
    )
    (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
    
    (if (is-some nft-uri)
        (begin
            (map-set NFTs (var-get nft-counter) {
                owner: (as-contract tx-sender),
                challenge-id: challenge-id,
                metadata-uri: (unwrap-panic nft-uri)
            })
            (var-set nft-counter (+ (var-get nft-counter) u1))
        )
        true
    )
    
    (map-set Challenges challenge-id {
        creator: tx-sender,
        title: title,
        reward-amount: reward-amount,
        participants: (list),
        completed: (list),
        active: true,
        end-height: end-height,
        nft-reward: nft-id
    })
    (var-set challenge-counter (+ challenge-id u1))
    (ok challenge-id)))

;; Submit a video for a challenge
(define-public (submit-video (title (string-ascii 50)) (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? Challenges challenge-id) (err u404)))
    )
    (asserts! (get active challenge) (err u405))
    (asserts! (< block-height (get end-height challenge)) (err u406))
    (try! (add-participant challenge-id tx-sender))
    (ok true)))

;; Vote on a video and update creator stats
(define-public (vote-video (video-id uint))
    (let (
        (video (unwrap! (map-get? Videos video-id) (err u404)))
        (current-votes (get votes video))
        (creator (get creator video))
        (creator-stats (default-to { reputation: u0, videos-created: u0, challenges-completed: u0, total-votes-received: u0 } 
                                 (map-get? UserStats creator)))
    )
    (map-set Videos video-id
        (merge video { votes: (+ current-votes u1) })
    )
    (map-set UserStats creator 
        (merge creator-stats { total-votes-received: (+ (get total-votes-received creator-stats) u1) })
    )
    (ok true)))

;; Complete a challenge and receive rewards
(define-public (complete-challenge (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? Challenges challenge-id) (err u404)))
        (reward (get reward-amount challenge))
        (completed-list (get completed challenge))
        (nft-id (get nft-reward challenge))
    )
    (asserts! (get active challenge) (err u405))
    (asserts! (is-none (index-of completed-list tx-sender)) (err u406))
    
    ;; Transfer STX reward
    (try! (as-contract (stx-transfer? reward (as-contract tx-sender) tx-sender)))
    
    ;; Transfer NFT if available
    (if (and (is-some nft-id) (is-eq (len completed-list) u0))
        (begin 
            (try! (as-contract (transfer (unwrap-panic nft-id) (as-contract tx-sender) tx-sender)))
            (update-leaderboard tx-sender true)
        )
        (update-leaderboard tx-sender false)
    )
    
    (map-set Challenges challenge-id
        (merge challenge { completed: (unwrap-panic (as-max-len? (append completed-list tx-sender) u50)) })
    )
    (ok true)))

;; Private Functions

(define-private (add-participant (challenge-id uint) (participant principal))
    (let (
        (challenge (unwrap! (map-get? Challenges challenge-id) (err u404)))
        (participants (get participants challenge))
    )
    (ok (map-set Challenges challenge-id
        (merge challenge { participants: (unwrap-panic (as-max-len? (append participants participant) u50)) })
    ))))

(define-private (update-leaderboard (user principal) (won-nft bool))
    (let (
        (current-entry (default-to { total-score: u0, challenges-won: u0, nfts-earned: u0 }
                                 (map-get? LeaderboardEntries user)))
    )
    (map-set LeaderboardEntries user {
        total-score: (+ (get total-score current-entry) u100),
        challenges-won: (+ (get challenges-won current-entry) u1),
        nfts-earned: (+ (get nfts-earned current-entry) (if won-nft u1 u0))
    })))

;; Read Only Functions

(define-read-only (get-challenge (challenge-id uint))
    (map-get? Challenges challenge-id))

(define-read-only (get-user-stats (user principal))
    (map-get? UserStats user))
    
(define-read-only (get-leaderboard-entry (user principal))
    (map-get? LeaderboardEntries user))

(define-read-only (get-nft-details (token-id uint))
    (map-get? NFTs token-id))

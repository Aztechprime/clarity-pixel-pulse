;; PixelPulse Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))

;; Data Variables
(define-data-var challenge-counter uint u0)

;; Data Maps
(define-map Challenges uint {
    creator: principal,
    title: (string-ascii 50),
    reward-amount: uint,
    participants: (list 50 principal),
    completed: (list 50 principal),
    active: bool,
    end-height: uint
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
    challenges-completed: uint
})

;; Public Functions

;; Create a new challenge
(define-public (create-challenge (title (string-ascii 50)) (reward-amount uint) (duration uint))
    (let (
        (challenge-id (var-get challenge-counter))
        (end-height (+ block-height duration))
    )
    (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
    (map-set Challenges challenge-id {
        creator: tx-sender,
        title: title,
        reward-amount: reward-amount,
        participants: (list),
        completed: (list),
        active: true,
        end-height: end-height
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

;; Vote on a video
(define-public (vote-video (video-id uint))
    (let (
        (video (unwrap! (map-get? Videos video-id) (err u404)))
        (current-votes (get votes video))
    )
    (map-set Videos video-id
        (merge video { votes: (+ current-votes u1) })
    )
    (ok true)))

;; Complete a challenge
(define-public (complete-challenge (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? Challenges challenge-id) (err u404)))
        (reward (get reward-amount challenge))
        (completed-list (get completed challenge))
    )
    (asserts! (get active challenge) (err u405))
    (asserts! (is-none (index-of completed-list tx-sender)) (err u406))
    (try! (as-contract (stx-transfer? reward (as-contract tx-sender) tx-sender)))
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

;; Read Only Functions

(define-read-only (get-challenge (challenge-id uint))
    (map-get? Challenges challenge-id))

(define-read-only (get-user-stats (user principal))
    (map-get? UserStats user))
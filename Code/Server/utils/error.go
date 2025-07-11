package utils

import (
	"github.com/gin-gonic/gin"
)

type ErrorCode string

const (
	InvalidPassword              ErrorCode = "invalid-password"
	CannotFetchUser              ErrorCode = "cannot-fetch-user"
	UserNotFound                 ErrorCode = "user-not-found"
	CannotCreateUser             ErrorCode = "cannot-create-user"
	NoClaims                     ErrorCode = "no-claims"
	CannotDecodeUser             ErrorCode = "cannot-decode-user"
	MissingFields                ErrorCode = "missing-fields"
	CannotHashPassword           ErrorCode = "cannot-hash-password"
	EmailAlreadyExists           ErrorCode = "email-already-exists"
	TestError                    ErrorCode = "test-error"
	TooManyRequests              ErrorCode = "too-many-requests"
	InviteNotFound               ErrorCode = "invite-not-found"
	UserSameEmailAsInvite        ErrorCode = "user-must-have-same-email-as-invite"
	InviteAlreadyExists          ErrorCode = "invite-already-exists-for-email-or-property"
	LeaseAlreadyExist            ErrorCode = "lease-already-exists-for-tenant-and-property"
	PropertyNotFound             ErrorCode = "property-not-found"
	PropertyNotYours             ErrorCode = "property-is-not-yours"
	NotAnOwner                   ErrorCode = "not-an-owner"
	NotATenant                   ErrorCode = "not-a-tenant"
	UserAlreadyExistsAsOwner     ErrorCode = "user-already-exists-as-owner"
	PropertyAlreadyExists        ErrorCode = "property-already-exists"
	PropertyNotAvailable         ErrorCode = "property-not-available"
	TenantAlreadyHasLease        ErrorCode = "tenant-already-has-lease"
	NoActiveLease                ErrorCode = "no-active-lease"
	LeaseNotFound                ErrorCode = "lease-not-found"
	CannotEndNonCurrentLease     ErrorCode = "cannot-end-non-current-lease"
	CannotArchiveNonFreeProperty ErrorCode = "cannot-archive-non-free-property"
	InvReportMustBeCurrentLease  ErrorCode = "inventory-report-must-be-linked-to-current-lease"
	NoLeaseInvite                ErrorCode = "no-pending-lease"
	DocumentNotFound             ErrorCode = "document-not-found"
	DamageNotFound               ErrorCode = "damage-not-found"
	DamageAlreadyExists          ErrorCode = "damage-already-exists"
	CannotUpdateFixedDamage      ErrorCode = "cannot-update-fixed-damage"
	DamageAlreadyFixed           ErrorCode = "damage-already-fixed"
	FailedLinkImage              ErrorCode = "failed-to-link-image"
	BadBase64OrUnsupportedType   ErrorCode = "bad-base64-string-or-unsupported-type"
	PropertyPictureNotFound      ErrorCode = "property-picture-not-found"
	UserProfilePictureNotFound   ErrorCode = "user-profile-picture-not-found"
	RoomNotFound                 ErrorCode = "room-not-found"
	RoomAlreadyExists            ErrorCode = "room-already-exists"
	RoomNotInThisProperty        ErrorCode = "room-not-in-this-property"
	FurnitureNotFound            ErrorCode = "furniture-not-found"
	FurnitureAlreadyExists       ErrorCode = "furniture-already-exists"
	FurnitureNotInThisRoom       ErrorCode = "furniture-not-in-this-room"
	InventoryReportAlreadyExists ErrorCode = "inventory-report-already-exists"
	InventoryReportNotFound      ErrorCode = "inventory-report-not-found"
	RoomStateAlreadyExists       ErrorCode = "room-state-already-exists"
	FurnitureStateAlreadyExists  ErrorCode = "furniture-state-already-exists"
	ErrorRequestChatGPTAPI       ErrorCode = "error-request-chatgpt-api"
	FailedSendEmail              ErrorCode = "failed-send-email"
)

type Error struct {
	Code  ErrorCode `json:"code"`
	Error string    `json:"error"`
}

func SendError(c *gin.Context, httpStatus int, code ErrorCode, err error) {
	if err == nil {
		c.JSON(httpStatus, Error{code, ""})
	} else {
		_ = c.Error(err)
		c.JSON(httpStatus, Error{code, err.Error()})
	}
}

func AbortSendError(c *gin.Context, httpStatus int, code ErrorCode, err error) {
	if err == nil {
		c.AbortWithStatusJSON(httpStatus, Error{code, ""})
	} else {
		_ = c.Error(err)
		c.AbortWithStatusJSON(httpStatus, Error{code, err.Error()})
	}
}

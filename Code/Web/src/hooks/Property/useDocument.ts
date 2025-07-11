import { useEffect, useState } from 'react'

import GetPropertyDocuments from '@/services/api/Owner/Properties/GetPropertyDocuments'
import UploadDocument from '@/services/api/Owner/Properties/UploadDocument'
import fileToBase64 from '@/utils/base64/fileToBase'

import { Document, UseDocumentReturn } from '@/interfaces/Property/Document'
import DeleteDocument from '@/services/api/Owner/Properties/DeleteDocument'

const useDocument = (
  propertyId: string,
  leaseId: string | undefined
): UseDocumentReturn => {
  const [documents, setDocuments] = useState<Document[] | null>(null)
  const [loading, setLoading] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)

  const fetchDocuments = async (propertyId: string) => {
    try {
      setLoading(true)
      setError(null)
      const response = await GetPropertyDocuments(propertyId, leaseId)
      setDocuments(response)
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'An error occurred while fetching the documents'
      )
      setDocuments(null)
    } finally {
      setLoading(false)
    }
  }

  const uploadDocument = async (
    file: File,
    documentName: string,
    propertyId: string
  ) => {
    try {
      setLoading(true)
      setError(null)

      const base64Data = await fileToBase64(file)
      const payload = {
        name: documentName,
        data: base64Data
      }

      const response = await UploadDocument(JSON.stringify(payload), propertyId)
      setDocuments(prevDocuments => {
        if (!prevDocuments) return [response]
        return [...prevDocuments, response]
      })
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'An error occurred while uploading the document'
      )
    } finally {
      setLoading(false)
    }
  }

  const deleteDocument = async (documentId: string) => {
    try {
      setLoading(true)
      setError(null)
      setDocuments(
        prevDocuments =>
          prevDocuments?.filter(doc => doc.id !== documentId) ?? []
      )
      await DeleteDocument(propertyId, documentId)
    } catch (err) {
      await fetchDocuments(propertyId)
      setError(
        err instanceof Error
          ? err.message
          : 'An error occurred while deleting the document'
      )
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (propertyId && leaseId) {
      fetchDocuments(propertyId)
    }
  }, [propertyId, leaseId])

  return {
    documents,
    loading,
    error,
    refreshDocuments: fetchDocuments,
    uploadDocument,
    deleteDocument
  }
}

export default useDocument

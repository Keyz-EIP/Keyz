import React, { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Modal, Form, DatePicker, FormProps, message } from 'antd'
import dayjs from 'dayjs'

import { Button, Input } from '@/components/common'
import InviteTenants from '@/services/api/Tenant/InviteTenant.ts'

import {
  InviteTenant,
  InviteTenantModalProps
} from '@/interfaces/Tenant/InviteTenant.ts'

const InviteTenantModal: React.FC<InviteTenantModalProps> = ({
  isOpen,
  onClose,
  propertyId
}) => {
  const { t } = useTranslation()
  const [form] = Form.useForm()
  const [loading, setLoading] = useState(false)

  const onFinish: FormProps<InviteTenant>['onFinish'] = async tenantInfo => {
    try {
      setLoading(true)
      // Destructurer avec des noms en camelCase
      const { start_date: startDate, end_date: endDate } = tenantInfo
      const formattedTenantInfo = {
        ...tenantInfo,
        propertyId
      }

      if (startDate && endDate) {
        if (dayjs(startDate).isAfter(dayjs(endDate))) {
          message.error(t('pages.real_property_details.date_error'))
          setLoading(false)
          return
        }
      }

      if (!startDate) {
        return
      }

      await InviteTenants(formattedTenantInfo)
      message.success(t('pages.real_property_details.invite_tenant'))
      setLoading(false)
      onClose(true)
    } catch (error: any) {
      if (error.response?.status === 409)
        message.error(t('pages.real_property_details.409_error'))
      setLoading(false)
    }
  }

  const onFinishFailed: FormProps<InviteTenant>['onFinishFailed'] = () => {
    message.error(t('pages.real_property_details.fill_fields'))
  }

  return (
    <Modal
      title={t('components.button.add_tenant')}
      open={isOpen}
      onCancel={() => onClose(false)}
      aria-labelledby="invite-tenant-modal-title"
      footer={[
        <Button key="back" type="default" onClick={() => onClose(false)}>
          {t('components.button.cancel')}
        </Button>,
        <Button key="submit" loading={loading} onClick={() => form.submit()}>
          {t('components.button.add')}
        </Button>
      ]}
    >
      <Form
        name="invite_tenant"
        onFinish={onFinish}
        onFinishFailed={onFinishFailed}
        layout="vertical"
        style={{ width: '90%', maxWidth: '500px', margin: '20px' }}
        form={form}
      >
        <Form.Item
          label={t('components.input.email.label')}
          name="tenant_email"
          rules={[
            { required: true, message: t('components.input.email.error') },
            { type: 'email', message: t('components.input.email.valid_email') }
          ]}
        >
          <Input
            id="tenant-email"
            type="email"
            placeholder={t('components.input.email.placeholder')}
            aria-label={t('components.input.email.placeholder')}
            aria-required="true"
            autoComplete="email"
          />
        </Form.Item>

        <Form.Item
          label={t('components.input.start_date.label')}
          name="start_date"
          rules={[{ required: true, message: t('form.error.start_date') }]}
        >
          <DatePicker
            id="start-date"
            style={{ width: '100%' }}
            aria-label={t('components.input.start_date.label')}
            aria-required="true"
            placeholder={t('components.input.start_date.placeholder')}
          />
        </Form.Item>

        <Form.Item
          label={t('components.input.end_date.label')}
          name="end_date"
          rules={[{ required: false, message: t('form.error.end_date') }]}
        >
          <DatePicker
            id="end-date"
            style={{ width: '100%' }}
            aria-label={t('components.input.end_date.label')}
            placeholder={t('components.input.end_date.placeholder')}
          />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default InviteTenantModal

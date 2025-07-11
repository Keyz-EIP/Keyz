import React from 'react'
import { useTranslation } from 'react-i18next'

import { Modal, Form, InputNumber } from 'antd'

import { Input } from '@/components/common'

import { AddFurnitureModalProps } from '@/interfaces/Property/Inventory/Room/Furniture/Furniture'

const AddStuffModal: React.FC<AddFurnitureModalProps> = ({
  isOpen,
  onOk,
  onCancel,
  form
}) => {
  const { t } = useTranslation()

  return (
    <Modal
      title={t(
        'pages.real_property_details.tabs.inventory.add_stuff_modal_title'
      )}
      open={isOpen}
      onOk={onOk}
      onCancel={onCancel}
      okText={t('components.button.add')}
      cancelText={t('components.button.cancel')}
      aria-labelledby="add-stuff-modal-title"
      aria-describedby="add-stuff-modal-description"
    >
      <div id="add-stuff-modal-description" className="sr-only">
        {t('pages.real_property_details.tabs.inventory.add_stuff_modal_title')}
      </div>

      <Form
        form={form}
        layout="vertical"
        aria-labelledby="add-stuff-modal-title"
      >
        <Form.Item
          name="stuffName"
          label={t('components.input.stuff_name.label')}
          rules={[
            {
              required: true,
              message: t('components.input.stuff_name.error')
            }
          ]}
        >
          <Input
            maxLength={20}
            showCount
            id="stuff-name-input"
            aria-label={t('components.input.stuff_name.label')}
            aria-required="true"
            placeholder={t('components.input.stuff_name.placeholder')}
          />
        </Form.Item>
        <Form.Item
          name="itemQuantity"
          label={t('components.input.item_quantity.label')}
          rules={[
            {
              required: true,
              message: t('components.input.item_quantity.error')
            },
            { type: 'number', min: 1, max: 1000 }
          ]}
        >
          <InputNumber
            min={1}
            max={1000}
            style={{ width: '100%' }}
            id="item-quantity-input"
            aria-label={t('components.input.item_quantity.label')}
            aria-required="true"
            placeholder={t('components.input.item_quantity.placeholder')}
          />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default AddStuffModal
